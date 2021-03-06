# -*-perl-*-

use strict;
use Test::More;
use lib "$ENV{LJHOME}/cgi-bin";
use LJ::Test;
require 'ljlib.pl';
use LJ::Protocol;

plan tests => 10;

my $u = temp_user();
my $newpass = "pass" . rand();
$u->set_password($newpass);
is($u->password, $newpass, "password matches");

my $res;

$res = do_req("postevent",
              'tz'         => 'guess',
              'subject'    => "new test post",
              'prop_current_mood' => "happy",
              'prop_current_music' => "music",
              'event'      => "this is my post.  btw, my password is $newpass!",
              );

is($res->{success}, "OK", "made a post")
    or die "failed to make post";

my $url    = $res->{url};
my $itemid = $res->{itemid};

my $gres = do_req("getevents",
                  'selecttype' => 'one',
                  'itemid' => $itemid,
                  );

is($gres->{success}, "OK", "got items");

my $eres = do_req("editevent",
                  itemid => $itemid,
                  event => "new version of post.  password still $newpass.",
                  subject => "editted subject",
                  prop_opt_noemail => 1);

is($eres->{success}, "OK", "did event");

$gres = do_req_deep("getevents",
                    'selecttype' => 'one',
                    'itemid' => $itemid,
                    );

is(ref $gres->{events}, "ARRAY", "got item list back (in deep API mode)")
    or die;
is(scalar @{$gres->{events}}, 1, "just one item")
    or die;
my $it = $gres->{events}[0];
is($it->{itemid}, $itemid, "is correct itemid");
is($it->{props}{revnum}, 1, "is 1st revision");

# now let's edit it again, setting all the props we got back
{
    my %props;
    foreach my $p (keys %{ $it->{props} }) {
        # revnum and revtime can't be manually specified; skip these
        next if $p eq "revnum";
        next if $p eq "revtime";
        $props{"prop_$p"} = $it->{props}{$p};
    }

    $eres = do_req("editevent",
                   itemid => $itemid,
                   event => "new version2 of post.  password still $newpass.",
                   subject => "editted subject2",
                   %props,
                   );
    is($eres->{success}, "OK", "did event, setting a bunch of round-tripped props");
}

# should be rev2 now
$gres = do_req_deep("getevents",
                    'selecttype' => 'one',
                    'itemid' => $itemid,
                    );

my $it = $gres->{events}[0];
is($it->{props}{revnum}, 2, "is 2nd revision now");


#use Data::Dumper;
#print Dumper($gres);


sub do_req {
    my ($mode, %args) = @_;
    $args{mode}     = $mode;
    $args{ver}      = 1; # supports unicode
    $args{user}     = $u->user;
    $args{password} = $u->password;

    my %res;
    my $flags = {};
    LJ::do_request(\%args, \%res, $flags);

    return \%res;
}

sub do_req_deep {
    my ($mode, %args) = @_;
    $args{ver}      = 1; # supports unicode
    $args{username} = $u->user;
    $args{password} = $u->password;

    my $flags = {};
    my $err;
    return LJ::Protocol::do_request($mode, \%args, \$err, $flags);
}

