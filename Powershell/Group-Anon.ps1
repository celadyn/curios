
function Get-EmailDomain($Email) {
    $Email -replace ".*@", ""
}


function Group-Anon {
    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $Inputs
        ,
        [Parameter()]
        $Property
        ,
        [Parameter()]
        [int]$AnonThreshold = 10
    )

    begin {

        # create container list
        $InputList = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($SingleInput in $Inputs){
            $InputList.Add($SingleInput)
        }
    }

    end {
        [array]$BaseGroup = $InputList | Group-Object -Property $Property

        $AboveThreshold,$BelowThreshold = $BaseGroup.Where({$_.Count -ge $AnonThreshold},"Split")

        [array]$OtherGroup = $BelowThreshold.Group | Group-Object {"Other"}

        $AllGroups = $AboveThreshold + $OtherGroup | Sort-Object Count -Descending

        $AllGroups
    }

}

<#
demo data

demo runner:

$em*2 | Group-Anon -Property {Get-EmailDomain $_} -AnonThreshold 40

# these are all COMPLETELY FAKE emails generated with an email generator

$em = @("kwilliams@comcast.net
juliano@outlook.com
sagal@sbcglobal.net
granboul@sbcglobal.net
jginspace@hotmail.com
jonathan@mac.com
lcheng@live.com
akoblin@sbcglobal.net
goresky@msn.com
aukjan@yahoo.com
mallanmba@mac.com
empathy@mac.com
evilopie@hotmail.com
stewwy@me.com
hoangle@live.com
catalog@yahoo.ca
louise@yahoo.com
nimaclea@gmail.com
parsimony@sbcglobal.net
sharon@icloud.com
kalpol@yahoo.ca
bcevc@live.com
malvar@outlook.com
dwsauder@icloud.com
mgreen@optonline.net
frederic@aol.com
granboul@sbcglobal.net
bescoto@mac.com
itstatus@aol.com
wikinerd@yahoo.ca
sinclair@mac.com
jespley@gmail.com
onestab@verizon.net
hoyer@att.net
jyoliver@live.com
houle@sbcglobal.net
tjensen@verizon.net
ullman@mac.com
jlbaumga@aol.com
stecoop@me.com
singh@outlook.com
mcsporran@gmail.com
hikoza@yahoo.com
killmenow@att.net
jamuir@verizon.net
rbarreira@me.com
stinson@sbcglobal.net
ilial@verizon.net
hstiles@optonline.net
rnelson@verizon.net
oechslin@yahoo.com
jimmichie@yahoo.ca
quinn@hotmail.com
andale@live.com
unreal@icloud.com
phizntrg@icloud.com
alias@hotmail.com
bartlett@comcast.net
josem@optonline.net
codex@gmail.com
kayvonf@sbcglobal.net
naupa@comcast.net
miturria@mac.com
violinhi@comcast.net
gavinls@yahoo.ca
isorashi@sbcglobal.net
linuxhack@live.com
enintend@hotmail.com
froodian@outlook.com
dbindel@comcast.net
jnolan@yahoo.com
timlinux@yahoo.com
kayvonf@verizon.net
michiel@mac.com
lpalmer@verizon.net
cameron@gmail.com
miami@att.net
barjam@yahoo.com
dpitts@sbcglobal.net
gboss@sbcglobal.net
druschel@gmail.com
fairbank@verizon.net
dmiller@optonline.net
penna@me.com
ccohen@hotmail.com
neuffer@msn.com
hakim@mac.com
rbarreira@verizon.net
frode@outlook.com
sinkou@sbcglobal.net
sarahs@optonline.net
kodeman@hotmail.com
ramollin@mac.com
hachi@comcast.net
kalpol@comcast.net
zavadsky@gmail.com
webinc@att.net
bdbrown@comcast.net
jaxweb@outlook.com
mallanmba@icloud.com
smartfart@hotmail.com
afifi@comcast.net
pizza@att.net
akoblin@msn.com
camenisch@hotmail.com
cremonini@mac.com
sumdumass@icloud.com
tkrotchko@att.net
alhajj@me.com
leviathan@att.net
chunzi@sbcglobal.net
moonlapse@msn.com
bahwi@mac.com
kronvold@verizon.net
bescoto@icloud.com
tattooman@msn.com
madanm@outlook.com
isaacson@att.net
gerlo@hotmail.com
maikelnai@optonline.net
mhassel@sbcglobal.net
odlyzko@live.com
mcnihil@aol.com
salesgeek@gmail.com
ilyaz@mac.com
tubesteak@hotmail.com
tedrlord@hotmail.com
jadavis@comcast.net
sjmuir@mac.com
gordonjcp@icloud.com
podmaster@sbcglobal.net
klaudon@aol.com
josephw@verizon.net
daveewart@yahoo.ca
dialworld@yahoo.ca
mgemmons@msn.com
sthomas@att.net
mavilar@outlook.com
danzigism@yahoo.com
demmel@msn.com
staikos@live.com
hoyer@live.com
tangsh@hotmail.com
khris@yahoo.ca
dobey@msn.com
bflong@hotmail.com
sharon@icloud.com
sarahs@optonline.net
rmcfarla@hotmail.com
jrifkin@hotmail.com
oster@live.com
mavilar@yahoo.com
research@sbcglobal.net
jdhildeb@icloud.com
knorr@aol.com
kwilliams@me.com
sartak@optonline.net
matloff@gmail.com
imightb@yahoo.ca
mlewan@yahoo.com
campbell@icloud.com
pedwards@mac.com
warrior@yahoo.ca
ilikered@me.com
rafasgj@me.com
nwiger@live.com
pkplex@icloud.com
devphil@hotmail.com
anicolao@hotmail.com
seanq@hotmail.com
fmerges@yahoo.ca
quantaman@msn.com
msusa@outlook.com
jmorris@att.net
jpflip@outlook.com
mastinfo@comcast.net
animats@att.net
trygstad@yahoo.ca
glenz@outlook.com
skythe@me.com
mfburgo@live.com
bhima@yahoo.ca
tskirvin@live.com
pkplex@aol.com
karasik@optonline.net
jrifkin@verizon.net
crusader@optonline.net
paley@hotmail.com
violinhi@live.com
majordick@sbcglobal.net
aschmitz@outlook.com
shang@att.net
world@outlook.com
ninenine@verizon.net
larry@sbcglobal.net
bahwi@me.com
pkilab@outlook.com
jnolan@icloud.com
camenisch@live.com
moinefou@aol.com
che.simon@ymail.com
v6h3tys81cax97xx8@hotmail.com
ritchie.cash@outlook.com
z607ik7yop@gmail.com
toby.price@rediffmail.com
jq9w2hhw1y0@outlook.com
zaine.ferrell@aol.com
stdkvpcnb5k6mnoamv7e@rediffmail.com
marlon.mullins@yahoo.com
iugfonkb9lsda6ndej@comcast.net
bradly.moore@msn.com
8etv0nnhac0jn@outlook.com
travis.west@msn.com
vj9q7584g37h1acql@outlook.com
kurtis.mcdaniel@googlemail.com
fks9iy3hvvvp@googlemail.com
callahan.beach@outlook.com
r3hwkg4drvw6mqynbld@gmail.com
sephiroth.fitzgerald@outlook.com
yhd78rblwk3vfhuthe42@aol.com
nilav.odonnell@googlemail.com
n7fklu6p9g1gk6hb@comcast.net
ijay.parrish@ymail.com
xa1jfuu4qhycsk1yux3v@ymail.com
regean.barber@msn.com
x2yik18bci@rediffmail.com
dyllan.rhodes@msn.com
9jm9z81eztgqc2@yahoo.com
ryan.huffman@msn.com
ahex03dg1ge856@msn.com
darragh.petty@msn.com
ibmv3qycuczb@gmail.com
karimas.rasmussen@gmail.com
swcnlr0q12743rm1vq01@ymail.com
kieran-scott.garrison@yahoo.com
hb5pmbm96szmpqm@hotmail.com
chris-daniel.bond@gmail.com
9ywz88zgzyv9ghmf@googlemail.com
zubair.noel@outlook.com
o4yj5oo1tyymhhe06@hotmail.com
jonah.garrett@outlook.com
fuvl8flmp3romojbof@googlemail.com
dillan.garrison@comcast.net
pxtqiz6myynw1ycq2ogm@aol.com
muneeb.baxter@gmail.com
qve1v5wynvh412z9@googlemail.com
reiss.coffey@rediffmail.com
eqorvenbubre28@msn.com
favour.kerr@aol.com
bocwo1es702zakxz@aol.com
abaan.charles@googlemail.com
q43vp164rcmv4@rediffmail.com
orrick.parks@comcast.net
td0gpbkqwa5xszz3gyqu@gmail.com
macaulay.barker@msn.com
da0aj4f032tnzpetu129@outlook.com
desmond.hull@googlemail.com
j84t6ts3hn95h9@aol.com
jayson.ball@gmail.com
vv7hdivz7mwijk6c@gmail.com
farren.eaton@ymail.com
cchlp8mo3h8lc@googlemail.com
elisau.melendez@comcast.net
jd3kgon7m6@aol.com
limo.love@msn.com
9zg0aie7pjn0anqdxrob@outlook.com
umut.stephens@rediffmail.com
z6xkk5lmbz5329yh@aol.com
konrad.fitzpatrick@gmail.com
45a5duftxhei9ugwgs5@rediffmail.com
daymian.hart@aol.com
ecccl08mnrf6v9@googlemail.com
morris.acevedo@comcast.net
shkdbfqwfn6pp95q7@googlemail.com
isa.foreman@yahoo.com
ni6fym8llbus14xek6u@gmail.com
nikita.craig@rediffmail.com
4gspcdqalzltzts273i9@googlemail.com
odin.hebert@ymail.com
3yiixyf3pr@msn.com
taegan.zamora@comcast.net
uzhhngv59xegdv@outlook.com
kieran.castaneda@yahoo.com
9cszs1i72zmoi9nfqkdo@ymail.com
aazaan.martinez@googlemail.com
za5bl3nb8ubps7t@comcast.net
lockey.sellers@yahoo.com
1fows3rf4zyhr6thca@googlemail.com
cruz.sosa@outlook.com
dru0qxaa9ei@hotmail.com
mika.david@aol.com
xype9gsp62c3144z3yp@ymail.com
ewan.ramirez@rediffmail.com
omfz1xhl3aqti0@hotmail.com
kiegan.myers@yahoo.com
845s5txo4qqcxj3@aol.com
harman.schroeder@outlook.com
wpgvrasjpwffk@yahoo.com
darwyn.suarez@yahoo.com
1x2rbs52zmwshqe@gmail.com
Zoe_Gosling3628@kyb7t.business
Makena_Robinson5772@6ijur.store
Eduardo_Harrington4978@nanoff.name
Jacqueline_Dwyer4132@ckzyi.center
Wendy_Antcliff3958@evyvh.host" -split "`r`n" -split "`r" -split "`n")



#>