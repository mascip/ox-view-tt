#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Plack::Test;
use FindBin;

use HTTP::Request::Common;
use Path::Class ();

{
    package Foo::Controller;
    use Moose;

    has view => (
        is       => 'ro',
        isa      => 'OX::View::TT',
        required => 1,
        handles  => ['render'],
    );

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;
        my ($r) = @_;
        (my $template = $AUTOLOAD) =~ s/.*:://;
        $template .= '.tt';
        my $defaults = $r->env->{'plack.router.match'}->route->defaults;
        $self->render($r, $template, $defaults);
    }
}

{
    package Foo;
    use OX;

    config template_root => sub {
        Path::Class::dir($FindBin::Bin)->subdir('data', '01', 'templates')
    };

    component View => 'OX::View::TT', (
        template_root => depends_on('/Config/template_root'),
    );

    component Controller => 'Foo::Controller', (
        view => depends_on('/Component/View'),
    );

    router as {
        route '/' => 'root.index', (
            content => 'Hello world',
        );
        route '/foo' => 'root.foo';
    }, (root => depends_on('/Component/Controller'));
}

my $foo = Foo->new;
my $view = $foo->resolve(service => '/Component/View');
isa_ok($view, 'OX::View::TT');
isa_ok($view->tt, 'Template');

test_psgi
    app => $foo->to_app,
    client => sub {
        my $cb = shift;

        {
            my $res = $cb->(GET 'http://localhost/');
            is($res->code, 200, "right code");
            is($res->content, "<b>Hello world</b>\n", "right content");
        }
        {
            my $res = $cb->(GET 'http://localhost/foo');
            is($res->code, 200, "right code");
            is($res->content, "<p>/foo</p>\n", "right content");
        }
    };

done_testing;