use inc::Module::Install;
name 'Plack-App-uWSGI';
all_from 'lib/Plack/App/uWSGI.pm';
readme_from 'lib/Plack/App/uWSGI.pm';

requires 'Plack' => '0.9980';
requires 'AnyEvent' => '5.34';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
