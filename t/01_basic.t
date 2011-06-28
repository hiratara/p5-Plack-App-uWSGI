use strict;
use warnings;
use File::Basename;
use File::Spec;
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

        # XXX Must move the directory for loading plugins.
        my $abs_testdir = File::Spec->rel2abs(dirname(__FILE__));
        chdir dirname $uwsgi;

        my $cmd = qq("$uwsgi" --plugins python -s :$port -w app) .
                  qq( --pythonpath "$abs_testdir");
        exec $cmd;
    },

    client => sub {
        my $port = shift;

        my $app = Plack::App::uWSGI->new(
            pass => "localhost:$port", modifier1 => "0"
        )->to_app;

        test_psgi $app, sub {
            my $cb = shift;
            my $res = $cb->(GET '/');
            is $res->code, 200;
            is $res->content, "OK\n";
        };
    },
);

done_testing;
