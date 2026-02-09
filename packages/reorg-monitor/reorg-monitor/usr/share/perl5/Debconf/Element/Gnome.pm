#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome;
use strict;
use utf8;
use Gtk3;
use Debconf::Gettext;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element);


sub init {
	my $this=shift;

	$this->hbox(Gtk3::VBox->new(0, 10));

	$this->hline1(Gtk3::HBox->new(0, 10));
	$this->hline1->show;
	$this->line1(Gtk3::VBox->new(0, 10));
	$this->line1->show;
	$this->line1->pack_end ($this->hline1, 1, 1, 0);

	$this->hline2(Gtk3::HBox->new(0, 10));
	$this->hline2->show;
	$this->line2(Gtk3::VBox->new(0, 10));
	$this->line2->show;
	$this->line2->pack_end ($this->hline2, 1, 1, 0);

	$this->vbox(Gtk3::VBox->new(0, 5));
	$this->vbox->pack_start($this->line1, 0, 0, 0);
	$this->vbox->pack_start($this->line2, 1, 1, 0);
	$this->vbox->show;

	$this->hbox->pack_start($this->vbox, 1, 1, 0);
	$this->hbox->show;
	
	$this->fill(0);
	$this->expand(0);
	$this->multiline(0);
}


sub addwidget {
	my $this=shift;
	my $widget=shift;

	if ($this->multiline == 0) {
	    $this->hline1->pack_start($widget, 1, 1, 0);
	}
	else {
	    $this->hline2->pack_start($widget, 1, 1, 0);
	}
}


sub adddescription {
	my $this=shift;
	my $description=to_Unicode($this->question->description);
	
	my $label=Gtk3::Label->new($description);
	$label->show;
	$this->line1->pack_start($label, 0, 0, 0);
}


sub addbutton {
	my $this=shift;
	my $text = shift;
	my $callback = shift;
	
	my $button = Gtk3::Button->new_with_mnemonic(to_Unicode($text));
	$button->show;
	$button->signal_connect("clicked", $callback);
	
	my $vbox = Gtk3::VBox->new(0, 0);
	$vbox->show;
	$vbox->pack_start($button, 1, 0, 0);
	$this->hline1->pack_end($vbox, 0, 0, 0);
}


sub create_message_dialog {
	my $this = shift;
	my $type = shift;
	my $title = shift;
	my $text = shift;
	
	my $dialog =
		Gtk3::Dialog->new_with_buttons(to_Unicode($title), undef,
		                               "modal", "gtk-close", "close");
	$dialog->set_border_width(3);
	
	my $hbox = Gtk3::HBox->new(0);
	$dialog->get_content_area->pack_start($hbox, 1, 1, 5);
	$hbox->show;
	
	my $alignment = Gtk3::Alignment->new(0.5, 0.0, 1.0, 0.0);
	$hbox->pack_start($alignment, 1, 1, 3);
	$alignment->show;
	
	my $image = Gtk3::Image->new_from_stock($type, "dialog");
	$alignment->add($image);
	$image->show;
	
	my $label = Gtk3::Label->new(to_Unicode($text));
	$label->set_line_wrap(1);
	$hbox->pack_start($label, 1, 1, 2);
	$label->show;
	
	$dialog->run;
	$dialog->destroy;
}


sub addhelp {
	my $this=shift;
	
	my $help=$this->question->extended_description;
	return unless length $help;
	
	$this->addbutton(gettext("_Help"), sub {
		$this->create_message_dialog("gtk-dialog-info",
		                              gettext("Help"), 
					     to_Unicode($help));
	});

	if (defined $this->tip ){
		$this->tip->set_tooltip_text(to_Unicode($help));
	}
}


sub value {
	my $this=shift;

	return '';
}


1
