-- Staff profile roles: yetkili | garson | mutfak
-- Existing rows default to garson (waiter).

ALTER TABLE public.staff_profiles
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'garson';

UPDATE public.staff_profiles
SET role = 'garson'
WHERE role IS NULL
   OR role NOT IN ('yetkili', 'garson', 'mutfak');

ALTER TABLE public.staff_profiles
  DROP CONSTRAINT IF EXISTS staff_profiles_role_check;

ALTER TABLE public.staff_profiles
  ADD CONSTRAINT staff_profiles_role_check
  CHECK (role IN ('yetkili', 'garson', 'mutfak'));
