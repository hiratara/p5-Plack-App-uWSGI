use strict;
use warnings;
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

1;
