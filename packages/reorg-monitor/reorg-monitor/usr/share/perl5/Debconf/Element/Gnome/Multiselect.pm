#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Multiselect;
use strict;
use Gtk3;
use utf8;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element::Gnome Debconf::Element::Multiselect);

use constant SELECTED_COLUMN => 0;
use constant CHOICES_COLUMN  => 1;

sub init {
	my $this=shift;
	my @choices = map { to_Unicode($_) } $this->question->choices_split;
        my %default=map { to_Unicode($_) => 1 } $this->translate_default;

	$this->SUPER::init(@_);
	$this->multiline(1);

	$this->adddescription;

        $this->widget(Gtk3::ScrolledWindow->new);
        $this->widget->show;
        $this->widget->set_policy('automatic', 'automatic');
	
	my $list_store = Gtk3::ListStore->new('Glib::Boolean', 'Glib::String');
	$this->list_view(Gtk3::TreeView->new($list_store));
	$this->list_view->set_headers_visible(0);

	my $renderer_toggle = Gtk3::CellRendererToggle->new;
	$renderer_toggle->signal_connect(toggled => sub {
		my $path_string = $_[1];
		my $model = $_[2];
		my $iter = $model->get_iter_from_string($path_string);
		$model->set($iter, SELECTED_COLUMN,
		            not $model->get($iter, SELECTED_COLUMN));
	}, $list_store);

	$this->list_view->append_column(
		Gtk3::TreeViewColumn->new_with_attributes('Selected',
			$renderer_toggle, 'active', SELECTED_COLUMN));
	$this->list_view->append_column(
		Gtk3::TreeViewColumn->new_with_attributes('Choices',
			Gtk3::CellRendererText->new, 'text', CHOICES_COLUMN));
	$this->list_view->show;

	$this->widget->add($this->list_view);

	for (my $i=0; $i <= $#choices; $i++) {
		my $iter = $list_store->append();
		$list_store->set($iter, CHOICES_COLUMN, $choices[$i]);
		if ($default{$choices[$i]}) {
			$list_store->set($iter, SELECTED_COLUMN, 1);
		}
	}
	$this->addwidget($this->widget);
	$this->tip($this->list_view);
	$this->addhelp;

	$this->fill(1);
	$this->expand(1);

}


sub value {
	my $this=shift;
	my $list_view = $this->list_view;
	my $list_store = $list_view->get_model();
	my ($ret, $val);
	
	my @vals;
	$this->question->template->i18n('');
	my @choices=$this->question->choices_split;
	$this->question->template->i18n(1);
	
	my $iter = $list_store->get_iter_first();
	for (my $i=0; $i <= $#choices; $i++) {
		if ($list_store->get($iter, SELECTED_COLUMN)) {
			push @vals, $choices[$i];
		}
		$list_store->iter_next($iter) or last;
	}

	return join(', ', $this->order_values(@vals));
}

*visible = \&Debconf::Element::Multiselect::visible;


1
