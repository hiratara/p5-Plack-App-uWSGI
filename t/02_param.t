use strict;
use warnings;
use File::Basename;
use Plack::App::uWSGI;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use Test::TCP;
use Test::More;
BEGIN { require(dirname(__FILE__) . "/util.pl") }

my $uwsgi = uwsgi_cmd;
plan skip_all => "no uwsgi command found" unless $uwsgi && -x $uwsgi;

Test::TCP::test_tcp(
    server => sub {
        my $port = shift;

        exec_uwsgi(
            $uwsgi => '--plugins', 'python', '-s', ":$port", '-w', 'app2',
        );
    },

    client => sub {
        my $port = shift;

        my $app = Plack::App::uWSGI->new(
            pass => "localhost:$port", modifier1 => "0",
            param => {SCRIPT_NAME => '/dummy'}
        )->to_app;

        test_psgi $app, sub {
            my $cb = shift;
            my $res = $cb->(GET '/');
            ok $res->is_success;
            is $res->header('X-Script-Name'), '/dummy';
        };
    },
);

done_testing;
