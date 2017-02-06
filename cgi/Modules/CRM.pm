package Modules::CRM;

#----------------------------------------------------------------------------
#
#   Copyright (C) 2017 - Robert Long
#
#   This file is part of ExSite WebWare (ExSite, for short).
#
#   ExSite is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   ExSite is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with ExSite; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#   Users requiring warranty coverage and/or support may arrange alternate
#   commercial licensing for ExSite, by contacting Exware Solutions 
#   via the website noted above.
#
#----------------------------------------------------------------------------

use strict;

# useful kernel libs; you can/should remove any of these that are not needed

use ExSite::Config;          # required
use ExSite::Input;           # optional input manager
use ExSite::Misc;            # optional utils
use ExSite::Util;            # optional utils
use ExSite::ML;              # optional markup-language generation
use ExSite::FormBuilder;     # optional form generation
use ExSite::ReportBuilder;   # optional report generation
use ExSite::Form;            # optional database manager


use Modules::Membership::Member;
use Modules::CRM::Task;

use JSON;
use CGI::Carp qw(fatalsToBrowser);

# recommended base class for plug-in modules

use Modules::BaseDCD;

# declare package globals

use vars qw(@ISA $ml);       # Perl inheritance global & markup language object

our @known_guest_status = ("contact", "lead", "sale lost", "sale won");

# define our class inheritance

@ISA = qw(Modules::BaseDCD); # inherit from this base class

# read method (sets up input data)

sub read {
    my ($this,$options) = @_;

    # default behaviour is to fetch overlayed GET and POST data
    # and store them in the object for use by other methods

    my $in = new ExSite::Input;
    $this->{input} = $in->combine;
    $this->{post}  = $in->post;
    $this->{query} = $in->query;
    $this->setup_queries();
    $ml = &get_obj("ML");
    if (my $uid = $this->{input}{uid}) {
        $this->{Member} = new Modules::Membership::Member(id=>$uid);
    }
}

# write method (builds output for regular web pages)

sub write {
    my ($this,$options) = @_;

    # declare a markup generator
    $ml = new ExSite::ML;

    # build a block of HTML to return to the CMS for inlining into
    # a template or other content.

    my $out;  # our output buffer

    # based on information in $options or $this->{input}, add HTML to $out.

    my $cmd = $this->{input}{pro};


    return $out;
}

# ioctl method (used by ExSite to query the module for its functionality)

sub ioctl {
    my $this = shift;
    $_ = shift;           # $_ is the ioctl request

    if (/isRestricted/) {
	return 0;
    }
    elsif (/isService/) {
	return 1;
    }
    elsif (/ModuleName/) {
	return $config{CRM}{ModuleName} || "CRM";
    } elsif (/Category/) {
    return ["Social", "Applications"];    
    }
    elsif (/Dependencies/) {
	return ["Membership"];
    }    
    elsif (/ControlPanel/) {
    return \&cron if ($this->{input}{cron});
	return \&ctrl_panel;
    }
    elsif (/Cron/) {
	return \&cron;
    }    
}

=pod
contact map types can be setup to map to uniquely identified contact types
in that case the system will check that the account only has one contact record with that type
=cut


#----------------------------------------------------------------------------
# Everything after this point consists of private methods.

# ctrl_panel() generates the contents of the administrator control panel

sub ctrl_panel {
    my $this = shift;

    # declare a markup generator
    $ml = new ExSite::ML;

    my $out;  # our output buffer
    if ($this->scope() eq "local") {
        $out .= $this->set_section_id();
    }
    
    my $cmd = $this->{input}{pro};
    if ($cmd eq "ajax_do_task") {
        my $id = $this->{input}{item_id};
        my $i = new Modules::CRM::Task(id=>$id);
        my $status = $this->{input}{off} ? "incomplete" : "complete";
        $i->setdata("status",$status);
        $i->save();
        return;
    } elsif ($cmd eq "toggle_complete") {
        $session{CRM_show_complete} = $this->show_complete() ? 0 : 1;
    }

    my $mode = $this->mode();
    my $label;
    my $heading = "Customer Relationship Management";
    my $title;
    if ($this->is_archive()) {
        $title = "Archive";
    } else {
        $title = ($mode eq "note") ? "Clipboard" : "To Do List";    
    }
    $out .= $this->menu();
    $out .= $ml->h1(uc($heading));
    my $options;
    my $add = ($mode eq "task") ?
        &ExSite::HTML::ResponsivePopup(label=>"add task",type=>"ajax",url=>$this->link(_bare=>2,pro=>"add_task")) :
        &ExSite::HTML::ResponsivePopup(label=>"add note",type=>"ajax",url=>$this->link(_bare=>2,pro=>"add_note"));
    $options .= $add;
    if ($mode eq "task") {
        $label = $this->show_complete ? "hide completed items" : "show completed items";
        my $toggle_status = $ml->a($label, {href=>$this->link(pro=>"toggle_complete")});
        $options .= $toggle_status;
    }
    
    $out .= &ExSite::HTML::ToolBar(tools=>[$options]);
    
    my $result;
    if ($cmd eq "item_form") {
        return $this->item_form();
    } elsif ($cmd eq "add_note") {
        return $this->add_note(); 
    } elsif ($cmd eq "add_task") {
        return $this->add_task();
    } elsif ($cmd eq "edit_item") {            
        return $this->edit_item($this->{input}{item_id});
    } elsif ($cmd =~ /^do_item$/) {
        $this->do_item();
        if (&ExSite::Config::fetch_diagnostics()) {
            $result = &ExSite::Config::show_diagnostics("raw");
            $result =~ s/\n/<br>/g;
        }
    } elsif ($cmd =~ /^archive_item$/) {
        $this->archive_item($this->{input}{item_id});
    } elsif ($cmd =~ /^unarchive_item$/) {
        $this->unarchive_item($this->{input}{item_id});        
    } elsif ($cmd =~ /^delete_item$/) {
        $this->delete_item($this->{input}{item_id});
    }
          
    my $action_pane = $result ? &ExSite::HTML::InfoBox(pane=>$ml->p($result)) : undef;
    my $taskpane = $action_pane . $this->taskpane();
    my $pipelinepane = $this->pipeline();
    
    my $left = &ExSite::HTML::BasicBox(title=>$title, pane=>$taskpane);
    my $right = &ExSite::HTML::BasicBox(title=>"Pipeline", pane=>$pipelinepane);
    
    my $left = $ml->div($left, {id=>"left_col"});
    my $right = $ml->div($right, {id=>"right_col"});
    $out .= $ml->div($left.$right, {id=>"wrap"});
    
    return $out;
}

# cron() allows this plug-in to respond to scheduling events.

sub cron {
    my ($this, $command, $type, $id) = @_;
    my $out;
    $this->setup_queries();
    my $now = new ExSite::Time;
    my $tasks = $share{DB}->get_query("tasks on date", $now->write("sql_date").'%');
    my $template = <<END;
<p>This is a reminder that the following task is due soon...<br>
<div style="border: 1px solid #bbb; padding: 10px">[[task]]</div>
<div style="border: 1px solid #bbb; padding: 5px 5px 5px 10px; background-color: #ccc; font-size: 90%">Due at [[time]] today [[relationship]]</div>
<p><a href="[[link]]">Open To Do List</a></p>
</p>
END
    foreach my $data (@$tasks) {
        my $task = new Modules::CRM::Task(data=>$data);
        my $task_time = $task->datetime;
        if (my $diff = $now->diff($task_time)) {
            my $owner = $task->owner();
            if ($diff > 0 && $diff < 3600 && !$task->is_done() && $owner) {
                next if (!$owner->email);
                my %merge = (
                    "link" => $this->reset_link(),
                    owner => $task->owner()->name(),
                    task => $task->getdata("value"),
                    "time" => $task->datetime() ? $task->datetime()->write("time") : undef
                );
                my $m = $task->member();
                if ($m) {
                    $merge{relationship} = $ml->a(&substitute("linked to [[name]]", {name=>$m->name(verbose=>1)}), 
                        {href=>$this->link_membership(section_id=>$m->gid(), uid=>$m->id())});
                }
                $out .= &substitute($template, \%merge);
                &ExSite::Mail::send(
                    to      => $task->owner()->email(),
                    from    => $share{DB}->owner_email(),
                    subject => "Task reminder",
                    body    => $out,
                );
                last;
            }
        }
    }
    return $out;
}

sub menu {
    my ($this, $evt) = @_;
    my $path = "$config{server}{HTMLpath}/_Modules/";
    my $links = [{
            label => "Notes",
            img   => "$config{server}{HTMLpath}/_ExSite/images/icons/content.png",
            url   => $this->reset_link(mode=>"note")},
        {
            label => "Tasks",
            img   => "$config{server}{HTMLpath}/_ExSite/images/icons/time.png",
            url   => $this->reset_link(mode=>"task")},
        {
            label => "Archive",
            img   => "$config{server}{HTMLpath}/_ExSite/images/icons/folder.png",
            url   => $this->reset_link(mode=>"archive")},
        ];
    my $out  = &ExSite::HTML::IconBar(links=>$links);
    return $out;
}

sub show_complete {
    my $this = shift;
    return 1 if ($this->mode() eq "note");
    return $session{CRM_show_complete};
}

sub is_do_task {
    my $this = shift;
    my $cmd = $this->{input}{pro};  
    my $type = $this->{input}{type};
    my $remind = $this->{input}{remind};
    if ($cmd eq "do_item" && ($type eq "task" || $remind)) {
        return 1;
    }
    return 0;
}

sub mode {
    my $this = shift;
    my $mode = $this->{input}{mode};
    if ($this->is_do_task() && $mode ne "archive") {
        # switch to task mode because user entered a task
        $mode = "task";
    }
    if ($mode) {
        return $mode;
    }
    return "task";
}

sub is_archive {
    my $this = shift;
    return $this->mode() eq "archive";
}

sub taskpane {
    my $this = shift;
    my $tasks = $this->todays_tasks();
    return $this->show_tasks($this->mode(),$tasks);
}

sub pipeline {
    my $this = shift;
    my $out;
    my $m = &ExSite::Module::get_module("Membership");
    my $guests = $share{DB}->get_query("all guests with status");
    my %index;
    my $total = 0;
    foreach my $m (@$guests) {
        if ($m->{status} =~ /contact|lead|sale won|sale lost/) {
            $index{$m->{status}}++;
            $total++;
        }
    }
    foreach my $status (@known_guest_status) {
        if ($status =~ /contact|lead|sale won|sale lost/) {
        my $uri = $this->membership_uri();
        $uri->query(pro=>"roster",status=>$status);
        my $url = $ml->a(ucfirst($status), {href=>$uri->write});
        my $count = $index{$status} || 0;
        my $percent = $total ? (($count / $total) * 100) : 0;
        my $color = $status eq "sale lost" ? "#db3340" : "#1fda9a";
        my $progress = $ml->div(
            $ml->div(undef,{style=>"background-color: $color; width: ${percent}\%",id=>"bar"}), {class=>"progress"});
        $out .= $ml->p($url.": $count ".$progress);
        }
    }
    $out .= $ml->div("You have a total of $total people in your pipeline (including previously won)", {class=>"pipeline_msg"});
    return $out;
}

sub membership_uri {
    my $this = shift;
    my $uri = new ExSite::URI;
    $uri->path_info("/Membership");
    return $uri;
}

#------------------------------------------------------------------------
# notes and tasks

sub item_form {
    my ($this,$item_id,$type) = @_;
    my $i = new Modules::CRM::Task(id=>$item_id);
    my $f = new ExSite::FormBuilder(method=>"post", enctype => "multipart/form-data");
    $type = $type || $i->getdata("type");
    my $label = $type || "note or task";
    my $placeholder = &substitute("Enter a [[label]][[include:name]] for [[name]][[/include:name]]", {label=>$label,name=>$this->member->name});
    $f->input(
        name => "value",
        type => "textarea",
        size => 180,
        placeholder => $placeholder,
        value => $i->getdata("value"),
        class => "styled"
    );
    my $t = new ExSite::Time;
    $t->add(1,"day");
    my $value = $i->getdata("date") || $t->write("sql_datetime");
    my $input = $share{DB}->input_exsite(datatype=>"datetime",
                      name=>"date",
                      value=>$value);
    my $input_date_id = "item-input-date";                      
    my %checkbox_attr = (type=>"checkbox",name=>"remind",prompt=>"Remind me");
    if ($type eq "task") {
        $checkbox_attr{checked} = "checked";
        $checkbox_attr{disabled} = 1;
        $input_date_id = "item-input-date-task";
    }
    $f->input(%checkbox_attr);
    my $files = $i->show_documents();
    my $upload = $ml->input(undef, {name => "uploads[]", type => "file", multiple => undef});
    $f->input(type => "preformatted", name => "uploads", input => $upload);
    $f->input(type => "preformatted", name => "date", input => $input);
    $f->input(type => "hidden", name => "pro", value => "do_item");
    $f->input(type => "hidden", name => "item_id", value => $item_id);
    $f->input(type => "hidden", name => "type", value => $type);
    my $member = $i->member();
    my $member_ok = ($member && $member->get()) ? 1 : 0;
    my $linked_member_id = $member_ok ? $member->id() : undef;
    my $autocomplete = $this->autocomplete($linked_member_id);
    if (!$this->member->id()) {
    # not currently on a member profile
    $f->input(name=>"uid", type => "formatted", input => $autocomplete, prompt => "Link this to a contact", size=>30);
    }
   
    my $contact_input;
    if ($member_ok) {
        my $link_span_id;
        if ($this->member->id()) {
            $link_span_id = "linked_contact_locked";
        } else {
            $link_span_id = "linked_contact";
        }
        $contact_input = "[[uid:prompt]]<br><span id=\"linked_contact_input\" style=\"display: none;\">[[uid:input]]</span>" .
            $ml->span($member->name(verbose=>1) . " &xotime;", {class=>"tag nofloat", id=>$link_span_id});
    } else {
        $contact_input = "[[uid:prompt]]<br><span id=\"linked_contact_input\">[[uid:input]]</span>" . 
            $ml->span(undef, {class=>"tag nofloat", id=>"linked_contact", style=>"display:none;"});
    }
    $f->template("<div>
        <div id=\"item-input-value\">[[value:input]]</div>
        <div id=\"item-input-remind\">[[remind:input]]&nbsp;[[remind:prompt]]</div>
        <div id=\"$input_date_id\">[[date:input]] <span class=\"item-bubble\">due date for this task - an email reminder will be sent if possible</span></div>
        <p id=\"item-input-upload\">[[uploads:input]] <span class=\"item-bubble\">You can select more than one file (ctrl-click on windows and command-click on mac).</span></p>
        <div id=\"item-files\">$files</div>
        <p>$contact_input</p>
        </div>");

    $f->buttons(submit=>"Save");
    my $out;
    $out .= $this->CRM_js();
    $out .= $f->make();
    return $out;
}

# recipient dropdown is a regular dropdown of member_id values or names of groups
# groups get translated to member_id value lists on server side
sub autocomplete {
    my ($this,$value) = @_;
    my $out;
    my @autocomplete;
    my %index = $this->recipient_index();
    foreach my $name (sort keys %index) {
	    my $item;
        $item->{value} = $index{$name};
        $item->{label} = $name;
	    push @autocomplete, $item;
    }
    my %opt;
    my $collection = JSON::to_json(\@autocomplete);
    $opt{type} = "text";
    my $id = &ExSite::Misc::safetext($opt{name});
    my $ml = &get_obj("ML");
    my $head;
    if (! $share{js}{jqueryui}) {
    $head .= $ml->script(undef,{type=>'text/javascript',src=>$config{jqueryui}});
    }
    if (! $share{autocomplete}) {
    $head .= $ml->link(undef,{rel=>'stylesheet', href=>"$config{server}{HTMLpath}/_ExSite/css/autocomplete.css"});
    $share{autocomplete} = 1;
    }
    $head .= $ml->script("\$(function() { var c = $collection; setup_acc('uid',c); });");
    $opt{head} = $head;
    $opt{name} = "uid";
    $opt{value} = $value;
    $opt{size} = 30;
    $out .= $share{DB}->input_html(%opt);
    return $out;
}

sub Membership {
    my $this = shift;
    return &ExSite::Module::get_module("Membership");
}

sub recipient_index {
    my $this = shift;
    my %index;
    my @member = $share{DB}->fetch_all("member");
    my $M = $this->Membership();
    foreach my $data (@member) {
        my $name =  $M->membername($data,1);
        $index{$name} = $data->{member_id};
    }
    return %index;
}

sub add_note {
    my ($this) = @_;
    return $this->item_form(undef,"note");
}

sub add_task {
    my ($this) = @_;
    return $this->item_form(undef,"task");
}

sub edit_item {
    my ($this,$item_id) = @_;
    return $this->item_form($item_id);
}

sub archive_item {
    my ($this,$item_id) = @_;
    my $i = new Modules::CRM::Task(id=>$item_id);
    $i->archive();
}

sub unarchive_item {
    my ($this,$item_id) = @_;
    my $i = new Modules::CRM::Task(id=>$item_id);
    $i->archive(1);
}

sub delete_item {
    my ($this,$item_id) = @_;
    my $i = new Modules::CRM::Task(id=>$item_id);
    $i->delete();
}

sub do_item {
    my $this = shift;
    my %data = $share{DB}->parse_parts(%{$this->{post}});
    if ($data{value}) {
        my $item = new Modules::CRM::Task();
        $item->setup($this->{input}{item_id});
        $config{max_upload_size} = 4194304;
        $item->setdata("info",$this->do_item_upload());
        my $uid = $data{uid} || $this->{input}{uid};
        $item->setdata("member_id", $uid);
        $item->setdata("type", $data{type} || "note");
        if ($this->is_do_task()) {
            $item->setdata("date", $data{date});
            $item->setdata("type", "task");
        }
        if (!$item->getdata("archive")) {
            $item->setdata("archive", "N");
        }
        $item->setdata("value", $data{value});
        $item->setdata("change_by", $share{DB}->my_uid);
        if (!$item->getdata("status")) {
            $item->setdata("status","incomplete");
        }
        $item->save();
    }
}

sub item_sort {
    my $fmt = "sql_datetime";
    my $a_date = new ExSite::Time();
    my $b_date = new ExSite::Time();

    if ($a->{archive} eq "Y" && $b->{archive} eq "Y") {
        $a_date->set($a->{ctime},$fmt);
        $b_date->set($b->{ctime},$fmt);
        my $cmp = $a_date->diff($b_date,$fmt);
        return $cmp;
    }    

    if ($a->{type} eq "note") {
        $a_date->set($a->{ctime},$fmt);
        $b_date->set($b->{ctime},$fmt);
        my $cmp = $a_date->diff($b_date,$fmt);
        return $cmp;
    }
    if ($b->{status} eq $a->{status}) {
        $a_date->set($a->{date},$fmt);
        $b_date->set($b->{date},$fmt);
        my $cmp = $b_date->diff($a_date,$fmt);
        return $cmp;        
    }



    return $b->{status} cmp $a->{status};
}

# status = incomplete|complete
sub todays_tasks {
    my $this = shift;
    my $type = $this->mode();
    my $today = new ExSite::Time;
    my $items;
    if ($this->is_archive()) {
        # archived items
        $items = $share{DB}->get_query("archived items");
    } elsif ($this->show_complete()) {
        # not archived items
        $items = $share{DB}->get_query("active items by type", ($type));
    } else {
        # incomplete and not archived
        $items = $share{DB}->get_query("incomplete items by type", ($type));
    }
    return $items;
}

sub setup_queries {
    my $this = shift;
    my $db   = $share{DB};

    $db->set_query(
        "active items by type", (
            sql => "select * from task where type = ? and archive != 'Y'",
            nparam => 1,
            mode   => "r",
            keys   => ["task"],
        )
    );

    $db->set_query(
        "archived items", (
            sql => "select * from task where archive = 'Y'",
            nparam => 0,
            mode   => "r",
            keys   => ["task"],
        )
    );

    $db->set_query(
        "incomplete items by type", (
            sql => "select * from task where type = ? and status = 'incomplete' and  archive != 'Y'",
            nparam => 1,
            mode   => "r",
            keys   => ["task"],
        )
    );

    $db->set_query(
        "tasks on date", (
            sql => "select * from task where date like ?",
            nparam => 1,
            mode   => "r",
            keys   => ["task"],
        )
    );

    my $status_list = join(',', map { "'$_'" } @known_guest_status);
    $db->set_query(
        "all guests with status",
        (
            sql =>
"select m.*,c.address,c.city,c.provstate,c.country,c.pcode,c.phone1,c.phone2,c.fax,c.email contact_email,c.web,c.privacy,(select status from member_status force index (member_id) where member_status.member_id=m.member_id and member_status.status in ($status_list) order by member_status_id desc limit 1) status from member m left join account a on a.member_id = m.member_id left join contact c on c.account_id = a.account_id group by member_id",
            nparam => 0,
            mode   => "r",
            keys   => ["member", "member_status", "contact"],
        )
    );    
    return;
}

sub show_tasks {
    my ($this,$mode,$items) = @_;
    my $type_label = ucfirst($mode);
    my $out;
    foreach my $item (sort item_sort @$items) {
        my $i = new Modules::CRM::Task(data=>$item);
        my $item_type = $i->getdata("type");
        next if ($mode ne "archive" && $item_type ne $mode);
        my $posted = new ExSite::Time();
        $posted->set($i->getdata("ctime"),"sql_datetime");
        my $date = new ExSite::Time;
        my $date_output;
        my $diffdays;
        my $date_class;        
        if ($i->getdata("date")) {
            $date->set($i->getdata("date"),"sql_datetime");
            my $time = $date->write("time");
            $diffdays = $date->diffdays(new ExSite::Time);
            if ($i->is_task()) {
                if ($i->getdata("status") eq "complete") {
                    $date_class = "item-date-hidden";
                }
                if ($date->in_past()) {
                    $diffdays = abs($diffdays);
                    $date_output = $diffdays > 1 ? $diffdays . " days overdue" : "overdue";
                    $date_class .= " item-date item-date-overdue";
                } elsif ($diffdays <= 0 && $diffdays >= -3) {
                    $date_output = &substitute("due on [[date]] at [[time]]",{date=>$date->write("date"),time=>$time});
                    $date_class .= " item-date item-date-near";                
                } else {
                    $date_output = "due on " . $date->write("date");
                    $date_class .= " item-date item-date-future-$diffdays";                    
                }
            }
        }
        my $post;
        my $post_class = "post";
        if ($posted->diffdays(new ExSite::Time) > 3) {
            $post = "on ".$posted->write("date");
        } elsif ($posted->write("ago") =~ /seconds/) {
            $post = "just now";
            $post_class = "post-now";
        } else {
            $post = $posted->write("ago");        
        }
        my $member = $i->owner();
        my $submitter = $member->name(verbose=>1);
        my %data = (
            body => $i->showdata("value"),
            submitter => $submitter,
            posted => $ml->span($post, {class=>$post_class}),
            date => $date_output ? $ml->span($date_output,{class=>"item-bubble $date_class"}) : undef,
        );
        if ($item_type eq "task") {
            my %checkbox_attr = (type=>"checkbox",name=>"task_".$i->id);
            if ($i->getdata("status") eq "complete") {
                $checkbox_attr{checked} = "checked";
            }        
            $data{checkbox} = $ml->input(undef, \%checkbox_attr);
        }
        my $documents = $i->show_documents();
        my $edit = &ExSite::HTML::ResponsivePopup(label=>"edit",type=>"ajax",url=>$this->link(_bare=>2,pro=>"edit_item",item_id=>$i->id));
        my $delete_url = $this->link(pro=>"delete_item",item_id=>$i->id);
        my $status = $i->getdata("status");
        my $relationship;
        if ($i->getdata("member_id") && !$share{Membership}{admin}) {
            my $uid = $i->getdata("member_id");
            my $m = $i->member();
            my $sid = $m->gid();
            if ($m->name(verbose=>1)) {
                $data{relationship} = $ml->a(&substitute("linked to [[name]]", {name=>$m->name(verbose=>1)}), {href=>$this->link_membership(section_id=>$sid,uid=>$uid,pro=>undef,item_id=>undef)});
            }
        }
        my $archive_label = $i->is_archived() ? "unarchive" : "archive";
        my $archive_url = $i->is_archived() ? 
            $this->link(pro=>"unarchive_item",item_id=>$i->id) : 
            $this->link(pro=>"archive_item",item_id=>$i->id);
        $out .= &substitute(
        "<div class='member-item'>
            <div class='item-value item-value-$item_type item-value-$status'>[[checkbox]] [[body]]</div>
            $documents            
            [[include:relationship]]<div class='relationship'>[[relationship]]</div>[[/include:relationship]]
            <span class='item-info'>posted by [[submitter]] [[posted]] [[date]]</span>
            <span class='item-tools'>
                <span class='item-tools-edit'>$edit</span>
                <span class='item-tools-archive'><a href='$archive_url'>$archive_label</a></span>
                <span class='item-tools-delete'><a href='$delete_url'>delete</a></span>
            </span>
        </div>", \%data);
    }
    return $ml->div(&substitute($ml->div("[[icon]] ${type_label}s"), {
            icon=>$ml->img(undef, {src=>"$config{server}{HTMLpath}/_ExSite/images/icons/content.png"}),
            }
        ),{class=>"item-heading"}) . $out;
}

sub link_membership {
    my ($this, %query) = @_;
    my $module = "Membership";
    my $base = "$config{server}{CGIpath}/$config{prog}{ctrlpanel}/$module?section_id=" . $this->get_section_id;
    my $uri  = new ExSite::URI;
    $uri->setup($base);
    $uri->query(%query);
    return $uri->write();
}

sub getlib {
    my ($this) = @_;
    my @album = $share{DB}->fetch_match("page", {
            section_id => $this->get_section_id,
            type       => "library",
            filename   => "CRM",
            status     => "active"
        });
    my $pid;
    if (scalar @album) {
        $pid = $album[0]->{page_id};
    } else {
        my $p = new ExSite::Page();
        $pid = $p->make({
                type           => "library",
                title          => "CRM documents",
                filename       => "CRM",
                description    => "documents uploaded to crm relating to customers",
                status         => "active",
                access         => "members",
                publish_method => "dynamic",
                section_id     => $this->get_section_id,
            });
    }
    return $pid;
}

sub do_item_upload {
    my ($this) = @_;
    my $out;
    my $pid = $this->getlib;
    my $in = new ExSite::Input;
    my $data = $in->post;
    my @uploads = $this->get_upload("uploads[]", $data);
    my $numfiles = scalar @uploads;
    my $i = new Modules::CRM::Task(id=>$data->{item_id});
    my @documents = split(/$config{form}{sepchar}/,$i->getdata("info"));
    foreach my $upload (@uploads) {
        my ($filename, $data) = split /$config{form}{sepchar}/, $upload;
        $filename = &clean_filename($filename);
        my $mimetype = &MimeType($filename);
        my $content = new ExSite::Content();
        my $t = new ExSite::Time;
        my $name = $t->get_ss . "_$filename";
        my $cid = $content->make({
                name => $name,
                description => undef,
                type => "design",
                page_id => $pid,
            }, {
                mime_type => $mimetype,
                fdata => $upload,
            }
        );
        push(@documents, $cid);
    }
    my $documents = join($config{form}{sepchar}, @documents);
    $ml->info(&substitute($msg{"You successfully uploaded [[count]] files $documents."}, {count => $numfiles}));
    return $documents;
}

sub get_upload {
    my ($this, $key, $data) = @_;
    my @fnames = split(/; /, $data->{$key});
    require CGI;
    my $cgi = CGI::new();
    my @fh  = $cgi->upload($key);
    my @uploads;
    my $i;
    foreach my $fh (@fh) {
        my $fname = &clean_filename($fnames[$i]);
        my $fdata = undef;
        my $size  = 0;

        # read file contents
        my $continue = 1;
        while ($continue) {
            $continue = read($fh, $fdata, 1024, $size);
            $size += $continue;
        }
        my $img = new ExSite::Image($fname, $fdata);
        push(@uploads, $img->encode);
        $i++;
    }
    return @uploads;
}

#------------------------------------------------------------------------
# contacts

sub contacts {
    my $this = shift;
    return $this->{Contacts} if ($this->{Contacts});
    if (my $c = $this->account->get_contacts()) {
        return $c;
    }
    return undef;
}

sub account {
    my $this = shift;
    return $this->{Account} if ($this->{Account});
    if (my $m = $this->member()) {
        if (my $a = $m->account()) {
            $this->{Account} = $a;
        }
    }
    return $this->{Account};
}

sub member {
    my ($this,$uid) = @_;
    return $this->{Member} if ($this->{Member});
    my $m = new Modules::Membership::Member(id=>$uid);
    $this->{Member} = $m;
    return $this->{Member};
}

sub scope {
    return "global";
}

sub reset_link {
    my ($this, %query) = @_;
    my $module = $this->module_name();
    my $base = "$config{server}{CGIpath}/$config{prog}{ctrlpanel}/$module?section_id=" . $this->get_section_id;
    my $uri  = new ExSite::URI;
    $uri->setup($base);
    $uri->query(%query);
    return $uri->write();
}

sub CRM_js {
    my $this = shift;
    if (!$share{CRM_files}) {
    $share{CRM_files} = 1;
    return $ml->script(undef, {type=>"text/javascript",src=>"$config{server}{HTMLpath}/_Modules/CRM/CRM.js"});
    }
}

1;
