#!/usr/bin/perl
#-----------------------------------------------------------------------
#
#   Copyright 2001-2007 Exware Solutions, Inc.  http://www.exware.com
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

package Modules::CRM::Task;

use strict;
use ExSite::Config;
use ExSite::Base;
use ExSite::Form;
use ExSite::Misc;
use ExSite::ML;
use ExSite::Object;

use vars qw(@ISA $ml);
@ISA = qw(ExSite::Object);

$ml = &get_obj("ML");

sub my_type { return "task" }

sub show_documents {
    my ($this,$item) = @_;
    my $out;
    my $db = $share{DB};
    my @docs = split($config{form}{sepchar},$this->getdata("info"));
    if (@docs) {
        my $sql = join(', ',@docs);
        my $sql = "select * from content where content_id in ($sql)";
        my @content_records = $share{DB}->custom_query($sql);
        my $nrec = scalar @content_records;
        foreach my $crec (@content_records) {
            my $listitem;
            my $c = new ExSite::Content(content => $crec, version => "newest");
            $c->set_context();
            my $url = $c->get_url;
            if ($c->has_content()) {
                my ($file, $size, $mime) = $c->get_fileinfo;
                if ($size) {
                    $out .= $ml->div($ml->a($file, {
                        href=>$url, 
                        class=>&MimeToFile($mime), 
                        download=>""}), {class=>"tag"});
                }
            }
        }
        return $out ? $ml->div($out, {class => "tag-list"}) : undef;
    }
    return undef;
}

sub archive {
    my ($this,$unarchive) = @_;
    my $flag = $unarchive ? "N" : "Y";
    $this->setdata("archive",$flag);
    $this->save();
}

sub status {
    my $this = shift;
    return $this->getdata("status");
}

sub is_task {
    my $this = shift;
    return $this->getdata("type") eq "task";
}

sub is_archived {
    my $this = shift;
    return $this->getdata("archive") eq "Y";
}

sub member {
    my $this = shift;
    my $uid = $this->getdata("member_id");
    if ($uid) {
        return &get_obj("member",$uid);
    }
    return undef;
}

sub owner {
    my $this = shift;
    my $uid = $this->getdata("change_by");
    if ($uid) {
        return &get_obj("member",$uid);
    }
    return undef;
}

sub datetime {
    my $this = shift;
    my $t = new ExSite::Time;
    if ($this->getdata("date") =~ /^2\d{3}-\d{2}-\d{2}/) {
        $t->set($this->getdata("date"), "sql_datetime");
        return $t;
    }
    return undef;
}

sub is_done {
    my $this = shift;
    return undef if (!$this->is_task);
    return $this->getdata("status") eq "complete" ? 1 : 0;
}

1;
