package Mojolicious::Plugin::SimpleSlides;

use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = 0.01;
$VERSION = eval $VERSION;

use File::Spec;
use File::Basename ();
use File::ShareDir ();

has 'base_href';

has 'column_align' => 'top';

has 'column_template'  => 'simple_slides_column';
has 'columns_template' => 'simple_slides_columns';

has 'column_width';

has [qw/first_slide last_slide/] => 1;

has 'layout' => 'simple_slides';

has 'static_path' => sub {
  my $local = File::Spec->catdir(File::Basename::dirname(__FILE__), 'SimpleSlides', 'public');
  return $local if -d $local;

  my $share = File::ShareDir::dist_dir('Mojolicious-Plugin-SimpleSlides');
  return $share if -d $share;

  warn "Cannot find static content for Mojolicious::Plugin::SimpleSlides, (checked $local and $share). The bundled javascript and css files will not work correctly.\n";
};

sub register {
  my ($plugin, $app, $conf) = @_;

  push @{ $app->renderer->classes }, __PACKAGE__;
  push @{ $app->static->paths     }, $plugin->static_path;

  $app->helper( simple_slides => sub { $plugin } );

  $app->helper( column  => \&_column );
  $app->helper( columns => \&_columns );

  $app->helper( prev_slide => sub {
    my $self = shift;
    my $slide = $self->stash('slide');
    $slide == $self->simple_slides->first_slide ? $slide : $slide - 1;
  });

  $app->helper( next_slide => sub {
    my $self = shift;
    my $slide = $self->stash('slide');
    $slide == $self->simple_slides->last_slide ? $slide : $slide + 1;
  });

  $app->helper( code_line => sub {
    shift->tag('pre' => class => 'code-line' => @_);
  });

  $app->routes->any( 
    '/:slide',
    { slide => $plugin->first_slide },
    [ slide => qr/\b\d+\b/ ],
    \&_action,
  );

  return $plugin;
}

# controller action callback

sub _action {
  my $c = shift;
  my $slide = $c->stash( 'slide' );
  $c->layout( $c->simple_slides->layout );
  $c->render( $slide ) || $c->render_not_found;
}

# helpers

sub _column { 
  my $c = shift;
  my $plugin = $c->simple_slides;
  my $content = pop || return;
  $content = ref $content ? $content->() : $content;

  my %args = @_;
  my $style = '';

  my $width = delete $args{width} // $plugin->column_width;        #/# highlight fix
  if ( $width ) {
    $style .= "width: $width%;";
  }

  if ( my $align = delete $args{align} || $plugin->column_align ) {
    $style .= "vertical-align: $align;";
  }
 
  return $c->render( 
    partial => 1, 
    'columns.style' => $style,
    'columns.column' => $content, 
    template => $plugin->column_template,
  );
}

sub _columns { 
  my $c = shift;
  return unless @_;
  my $content = shift->();
  return $c->render( 
    partial => 1, 
    'columns.content' => $content,
    template => $c->simple_slides->columns_template,
  );
}

1;

__DATA__

@@ simple_slides_column.html.ep
% my @tag = qw/div class column/;
% if ( my $style = stash 'columns.style' ) { push @tag, style => $style } 
%= tag @tag, begin
  %= stash 'columns.column'
% end

@@ simple_slides_columns.html.ep
<div class="columns-wrapper">
  <div class="columns">
    %= stash 'columns.content'
  </div>
</div>

@@ layouts/simple_slides.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    % if ( my $href = simple_slides->base_href ) {
      %= tag base => href => $href
    % }
    % if ( __PACKAGE__->can('ppi') ) {
      %= stylesheet '/ppi.css';
      %= javascript '/ppi.js';
    % }
    %= stylesheet '/simple_slides.css'
    %= javascript '/mousetrap.min.js'
    %= javascript begin
      Mousetrap.bind(['right', 'down', 'pagedown'], function(){
        window.location = "<%= url_for slide => { slide => next_slide } %>";
      });
      Mousetrap.bind(['left', 'up', 'pageup'], function(){
        window.location = "<%= url_for slide => { slide => prev_slide } %>";
      });
    % end
  </head>
  <body>
    <div class="container">
      <h1 class="center"><%= title %></h1>
      <div id="main">
        %= content
      </div>
      <div class="nav">
        <div class="nav-item">
          %= link_to Previous => slide => { slide => prev_slide }
        </div>
        <div class="nav-item">
          %= "Page $slide / " . simple_slides->last_slide
        </div>
        <div class="nav-item">
          %= link_to Next => slide => { slide => next_slide }
        </div>
      </div>
    </div>
  </body>
</html>

__END__

=head1 NAME

Mojolicious::Plugin::SimpleSlides - Create a presentation using Mojolicious

=head1 DESCRIPTION

This module has been extracted from a talk gave at Chicago.pm. I have rushed it out before the talk, it has almost no tests or documentation. For the moment its use is at your own risk.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin::PPI>

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Mojolicious-Plugin-SimpleSlides>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
