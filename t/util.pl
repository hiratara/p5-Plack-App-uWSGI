use strict;
use warnings;
use File::Basename qw/dirname/;
use File::Spec;

sub which($) {
    my ($name) = @_;

    for my $dir (File::Spec->path) {
        my $path = File::Spec->catfile($dir, $name);
        -x $path and return $path;
    }

    return;
}

sub uwsgi_cmd() {
    $ENV{UWSGI_BIN_PATH} || which 'uwsgi';
}

sub shell_quote($) {
    my $opt = shift;
    $opt =~ / / or return $opt;
    $opt =~ s/"/\\"/g;
    return qq("$opt");
}

sub exec_uwsgi {
    my ($uwsgi, @options) = @_;

    # XXX Must move the directory for loading plugins.
    my $abs_testdir = File::Spec->rel2abs(dirname(__FILE__));
    chdir dirname $uwsgi;

    my $cmd = join ' ', map {shell_quote $_} $uwsgi, @options,
                                             '--pythonpath', $abs_testdir;
    exec $cmd;
}

1;
