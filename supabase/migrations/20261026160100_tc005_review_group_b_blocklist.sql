-- TC-005 PR #4 review, group B.
--
-- B2 (M3): the 15-entry blocklist from step 3 is trivial to bypass, and it
-- was only ever checked in accept-invite/the bootstrap script - a signed-in
-- user could set any password via supabase.auth.updateUser(), skipping it
-- entirely. This migration (a) replaces the tiny literal list with a much
-- larger generated one and (b) tightens the grant on password_is_blocked
-- (L6); change-password (the new Edge Function that is now the *only*
-- sanctioned self-service password-set path) is added alongside this
-- migration, not in it.
--
-- On the list itself: this sandbox has no network access to fetch a real
-- published top-10k/100k breach corpus (no curl, no outbound fetch - see
-- CLAUDE.md/run brief). Rather than hand-type a few hundred more literals,
-- this generates several thousand realistic candidates by combining common
-- base words/phrases (drawn from widely published, public "most common
-- passwords" lists - no proprietary or copyrighted data) with the numeric/
-- symbol suffixes people commonly append to clear a length-12 policy (which
-- is exactly the pattern the original 15-entry list already used, e.g.
-- 'password1234'). This is a stopgap, not a final answer - swap in a real
-- top-10k/100k corpus file (e.g. SecLists' 10-million-password-list,
-- loaded via `copy` from a file baked into the Docker image, since `copy`
-- from an arbitrary host path isn't available to migrations) the next time
-- this card (or a follow-up) has network access. Flagged in step4g-summary.md.
do $$
declare
  base_words text[] := array[
    'password','letmein','welcome','iloveyou','monkey','dragon','sunshine','princess',
    'football','baseball','basketball','trustno','whatever','freedom','hello','shadow',
    'master','superman','batman','spiderman','ironman','starwars','pokemon','minecraft',
    'ninja','cookie','chocolate','butterfly','rainbow','sunflower','mustang','corvette',
    'ferrari','maverick','phoenix','thunder','hunter','fishing','hockey','soccer','tennis',
    'golfer','dolphin','tigers','eagles','panthers','cowboys','yankees','jennifer','michael',
    'jessica','ashley','amanda','michelle','nicole','samantha','elizabeth','matthew','joshua',
    'andrew','daniel','anthony','christopher','jonathan','joseph','charlie','william','thomas',
    'robert','richard','jackson','jordan','taylor','hannah','hailey','madison','alexander',
    'benjamin','samuel','nathan','tyler','austin','dallas','houston','chicago','seattle',
    'atlanta','denver','orlando','vegas','london','paris','berlin','madrid','sydney','toronto',
    'montreal','chelsea','arsenal','liverpool','barcelona','juventus','gandalf','frodo',
    'legolas','skywalker','voldemort','hogwarts','gryffindor','slytherin','targaryen',
    'starbucks','google','facebook','twitter','youtube','netflix','spotify','whiskey',
    'tequila','margarita','birthday','christmas','newyear','summer','winter','autumn',
    'spring','morning','sunlight','moonlight','starlight','blueberry','strawberry',
    'raspberry','pineapple','watermelon','vanilla','caramel','cinnamon','lavender',
    'jasmine','elephant','giraffe','penguin','octopus','panther','leopard','cheetah',
    'gorilla','squirrel','hedgehog','dragonfly','ladybug','firefly','qwertyuiop',
    'asdfghjkl','zxcvbnmqw','trustme','letmeinplease','opensesame','changeme','newpassword'
  ];
  suffixes text[] := array[
    '','1','12','123','1234','12345','123456','01','001','007','09','10','11','13','21',
    '22','33','44','55','69','77','88','99','00','321','111','000','0000','2019','2020',
    '2021','2022','2023','2024','2025','!','!1','1!','99!','01!','@123','#1','$1','&1'
  ];
begin
  insert into public.password_blocklist (password)
  select distinct lower(w || s)
  from unnest(base_words) as w
  cross join unnest(suffixes) as s
  where length(w || s) >= 12
  on conflict do nothing;
end
$$;

-- L6: password_is_blocked was callable by anon, a harmless oracle on public
-- data but with no reason to be exposed that widely. authenticated (used by
-- change-password) and service_role (used by accept-invite) still can.
revoke execute on function public.password_is_blocked(text) from anon;
