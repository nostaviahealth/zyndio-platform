-- TC-011 gate fix: 20261027120000 (M3) replaced the TC-005 generated
-- stopgap blocklist (20261026160100) with a straight import of SecLists'
-- real 10k-most-common.txt, truncating the table first. That drop the
-- base-word + common-suffix compound variants the stopgap generated (e.g.
-- 'sunshine2024', 'chocolate@123') - the only blocklist entries that also
-- clear GoTrue's lower_upper_letters_digits_symbols + 12-char policy, so
-- they're the only way to exercise "a character-class-valid password can
-- still be on the blocklist" (tests/integration/password-hardening.test.ts,
-- tests/integration/admin-actions.test.ts). Re-adds the same generation
-- (same public base words, same suffix list) on top of the real import
-- rather than replacing it, so both the real corpus and the compound
-- variants are blocked. Not a revert of M3 - the base SecLists list stays.
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
