-- Care team and diet plan fixes found in review (2026-11-26).
-- 1. accept_recommendation: the doctor must still be on the patient's care team (and still verified,
--    matching 0004's rule that unverifying a doctor cuts off their access), and accepting a diet plan
--    also applies the plan's targets (the screen promised "current -> plan" targets but nothing changed).
-- 2. Revoking a care link declines that doctor's pending recommendations, so they can't be accepted later.
-- 3. activate_diet_plan: switches the active plan in one transaction (two requests could leave none active);
--    a doctor-authored plan carries its targets, like accepting it did.

-- Internal: writes a targets object onto a profile as doctor-set. Keys left out keep their value.
create function apply_doctor_targets(patient uuid, t jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if t is null or jsonb_typeof(t) <> 'object' or t = '{}'::jsonb then return; end if;
  update profiles set
    kcal_target = coalesce((t ->> 'kcal_target')::numeric, kcal_target),
    protein_g   = coalesce((t ->> 'protein_g')::numeric, protein_g),
    carbs_g     = coalesce((t ->> 'carbs_g')::numeric, carbs_g),
    fat_g       = coalesce((t ->> 'fat_g')::numeric, fat_g),
    sat_fat_g   = coalesce((t ->> 'sat_fat_g')::numeric, sat_fat_g),
    sodium_mg   = coalesce((t ->> 'sodium_mg')::numeric, sodium_mg),
    fiber_g     = coalesce((t ->> 'fiber_g')::numeric, fiber_g),
    targets_source = 'doctor'
  where id = patient;
end $$;

create or replace function accept_recommendation(rec_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  rec recommendations;
  plan jsonb;
begin
  select * into rec from recommendations
   where id = rec_id and patient_id = auth.uid() and status = 'pending' for update;
  if not found then raise exception 'Recommendation not found'; end if;
  if not exists (select 1 from care_links l join profiles d on d.id = l.doctor_id
                  where l.doctor_id = rec.doctor_id and l.patient_id = rec.patient_id and l.status = 'accepted'
                    and d.verified_at is not null) then
    raise exception 'This doctor is no longer on your care team';
  end if;

  if rec.kind = 'targets' then
    perform apply_doctor_targets(rec.patient_id, rec.payload -> 'targets');
  elsif rec.kind = 'diet_plan' then
    plan := rec.payload -> 'diet_plan';
    update diet_plans set is_active = false where user_id = rec.patient_id and is_active;
    insert into diet_plans (user_id, author_id, condition_id, name, notes, targets, meals, is_active)
    values (rec.patient_id, rec.doctor_id, plan ->> 'condition_id', plan ->> 'name', plan ->> 'notes',
            coalesce(plan -> 'targets', '{}'), coalesce(plan -> 'meals', '[]'), true);
    perform apply_doctor_targets(rec.patient_id, plan -> 'targets');
  end if;

  update recommendations set status = 'accepted', responded_at = now() where id = rec_id;
end $$;

create function decline_recommendations_on_revoke() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update recommendations set status = 'declined', responded_at = now()
   where doctor_id = new.doctor_id and patient_id = new.patient_id and status = 'pending';
  return new;
end $$;

create trigger care_links_revoke_declines after update of status on care_links
  for each row when (new.status = 'revoked' and old.status is distinct from 'revoked')
  execute function decline_recommendations_on_revoke();

create function activate_diet_plan(plan_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  p diet_plans;
begin
  select * into p from diet_plans where id = plan_id and user_id = auth.uid() for update;
  if not found then raise exception 'Plan not found'; end if;
  update diet_plans set is_active = false where user_id = p.user_id and is_active and id <> p.id;
  update diet_plans set is_active = true where id = p.id;
  -- A null author is a doctor who deleted their account (0003); the plan is still theirs, not the patient's.
  if p.author_id is distinct from p.user_id then perform apply_doctor_targets(p.user_id, p.targets); end if;
end $$;

revoke execute on function apply_doctor_targets(uuid, jsonb), decline_recommendations_on_revoke(),
  activate_diet_plan(uuid) from public, anon, authenticated;
grant execute on function activate_diet_plan(uuid) to authenticated;
