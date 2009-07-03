#! /usr/bin/perl -w

use warnings;
use strict;
use Carp;
use YAML::Syck qw/Load Dump/;
#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;

=head1 DESCRIPTION

Map intermediate type in earlier generated typemap_list and
typemap_template into known primitive type.

=cut

sub usage {
    print << "EOU";
usage          : $0 [template] [output_file] <typemap> <typemap_template>
template       : -t <template_file>
output_file    : -o <file_path>
EOU
    exit 1;
}

sub study_type {
    my ( $ntype, $type, $known_primitive_type, $typemap, ) = @_;
    
    my $type_primitive;
    # patch known pattern
    $type =~ s/(?:CONST_)?T_(?:GENERIC|PTR|UNION)_PTR/T_PTR/;
    
    if (exists $known_primitive_type->{$type}) {
        $type_primitive = $type;
    }
    # class/struct
    elsif ($type =~ m/^(?:CONST_)?T_(?:CLASS|STRUCT)_PTR$/o) {
        $type_primitive = 'T_PTROBJ';
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:CLASS|STRUCT)_PTR(?:_REF)?$/o) {
        $type_primitive = 'T_PTROBJ';
        if ($type =~ m/_REF$/o) {
            # add non-ref part as known type if it is missing
            ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
            $typemap->{$noref_ntype} = 'T_PTROBJ' unless 
              exists $typemap->{$noref_ntype};
        }
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:CLASS|STRUCT)_REF$/o) {
        # FIXME: maybe need to marshal by new
        # TODO:  switch to 'T_OBJECT'
        $type_primitive = 'T_REFOBJ';
        # add non-ref part as known type if it is missing
        ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
        $typemap->{$noref_ntype} = 'T_OBJECT' unless 
          exists $typemap->{$noref_ntype};
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:CLASS|STRUCT)$/o) {
        $type_primitive = 'T_OBJECT';
    }
    # template class
    elsif ($type =~ m/^(?:CONST_)?T_(?:[^\_]+)__.+(?<!_)_PTR$/o) {
        $type_primitive = 'T_PTROBJ';
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:[^\_]+)__.+(?<!_)_PTR(?:_REF)?$/o) {
        $type_primitive = 'T_PTROBJ';
        if ($type =~ m/_REF$/o) {
            # add non-ref part as known type if it is missing
            ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
            $typemap->{$noref_ntype} = 'T_PTROBJ' unless 
              exists $typemap->{$noref_ntype};
        }
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:[^\_]+)__.+(?<!_)_REF$/o) {
        # FIXME: maybe need to marshal by new
        # TODO:  switch to 'T_OBJECT'
        $type_primitive = 'T_REFOBJ';
        # add non-ref part as known type if it is missing
        ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
        $typemap->{$noref_ntype} = 'T_OBJECT' unless 
          exists $typemap->{$noref_ntype};
    }
    elsif ($type =~ m/^(?:CONST_)?T_(?:[^\_]+)__.+$/o) {
        $type_primitive = 'T_OBJECT';
    }
    # char
    elsif ($type =~ m/^(?:CONST_)?T_(?:U_)?CHAR_PTR$/o) {
        $type_primitive = 'T_PV';
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:U_)?CHAR)_REF$/o) {
        $type_primitive = $1;
    }
    # fpointer
    elsif ($type =~ m/^(?:CONST_)?T_FPOINTER_/o) {
        $type_primitive = 'T_PTR';
    }
    # generic pointer
    elsif ($type =~ m/^(?:CONST_)?T_PTR_REF$/o) {
        $type_primitive = 'T_PTRREF';
        # add non-ref part as known type if it is missing
        ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
        $typemap->{$noref_ntype} = 'T_PTR' unless 
          exists $typemap->{$noref_ntype};
    }
    # array
    elsif ($type =~ m/^T_ARRAY_/o) {
        $type_primitive = 'T_PTR';
    }
    # built-in type
    elsif ($type =~ m/^(?:CONST_)?((T_(?:I|U|N)V)_PTR)$/o) {
        $type_primitive = $1;
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:I|U|N)V)(?:_REF)?$/o) {
        $type_primitive = $1;
        if ($type =~ m/_REF$/o) {
            # add non-ref part as known type if it is missing
            ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
            $typemap->{$noref_ntype} = $type_primitive unless 
              exists $typemap->{$noref_ntype};
        }
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:U_)?(?:INT|SHORT|LONG)_PTR)$/o) {
        $type_primitive = $1;
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:U_)?(?:INT|SHORT|LONG))(?:_REF)?$/o) {
        $type_primitive = $1;
        if ($type =~ m/_REF$/o) {
            # add non-ref part as known type if it is missing
            ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
            $typemap->{$noref_ntype} = $type_primitive unless 
              exists $typemap->{$noref_ntype};
        }
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:ENUM|BOOL|FLOAT|DOUBLE)_PTR)$/o) {
        $type_primitive = $1;
    }
    elsif ($type =~ m/^(?:CONST_)?(T_(?:ENUM|BOOL|FLOAT|DOUBLE))(?:_REF)?$/o) {
        $type_primitive = $1;
        if ($type =~ m/_REF$/o) {
            # add non-ref part as known type if it is missing
            ( my $noref_ntype = $ntype ) =~ s/\s*&\s*$//o;
            $typemap->{$noref_ntype} = $type_primitive unless 
              exists $typemap->{$noref_ntype};
        }
    }
    elsif ($type =~ m/^(?:CONST_)?T_PV_REF$/o) {
        $type_primitive = 'T_PV';
    }
    else {
        $type_primitive = 'T_UNKNOWN';
    }
    return $type_primitive;
}

sub get_known_primitive_types {
    my ( $type_template, ) = @_;
    
    local ( *TEMPLATE, );
    open TEMPLATE, '<', $type_template or 
      croak("cannot open file to read: $!");
    my $primitive_type_map = {};
    while (<TEMPLATE>) {
        if (m/^\s*\[\%-?\s+CASE\s+'([^']+)'\s+-?\%\]\s*$/o) {
            $primitive_type_map->{$1}++;
        }
    }
    close TEMPLATE;
    return $primitive_type_map;
}

sub load_typemap {
    my ( $ftypemap, ) = @_;
    
    local ( *TYPEMAP, );
    open TYPEMAP, '<', $ftypemap or 
      croak("cannot open file to read: $!");
    my $cont = do { local $/; <TYPEMAP> };
    close TYPEMAP;
    return Load($cont);
}

sub dump_typemap {
    my ( $typemap, $fout, ) = @_;
    
    my $write_typemap = sub {
        my ( $typemap, $output, ) = @_;
        
        print $output Dump($typemap);
    };
    local ( *OUTPUT, );
    if ($fout) {
        open OUTPUT, '>', $fout or 
          croak("cannot open file to write: $!");
        $write_typemap->($typemap, \*OUTPUT);
        close OUTPUT or croak("cannot write to file: $!");
    }
    else {
        $write_typemap->($typemap, \*STDOUT);
    }
}

sub main {
    my $ftemplate   = '';
    my $fout        = '';
    my $h           = '';
    GetOptions(
        't=s'    => \$ftemplate,
        'o=s'    => \$fout, 
        'h|help' => \$h, 
    );
    usage() if $h;
    usage() unless @ARGV;
    my ( $ftypemap, $ftypemap_template, ) = @ARGV;
    croak("template not found: $ftemplate") unless -f $ftemplate;
    croak("typemap not found: $ftypemap") unless -f $ftypemap;
    croak("typemap_template not found: $ftypemap_template") unless 
      -f $ftypemap_template;
    
    my $known_primitive_type = get_known_primitive_types($ftemplate);
    my $typemap = load_typemap($ftypemap);
    my $typemap_template = load_typemap($ftypemap_template);
    # merge inner types in template
    foreach my $tt_entry (@$typemap_template) {
        foreach my $k (keys %$tt_entry) {
            if ($k =~ m/^(.+)_type$/o) {
                my $ntype_key = $1. '_ntype';
                $typemap->{$tt_entry->{$k}} = $tt_entry->{$ntype_key}
                  unless exists $typemap->{$k};
            }
        }
    }
    my $rc = 0;
    foreach my $ntype (keys %$typemap) {
        my $type = $typemap->{$ntype};
        my $type_primitive = study_type(
            $ntype, $type, $known_primitive_type, $typemap);
        if ($type_primitive eq 'T_UNKNOWN') {
            print STDERR "unknown type: $type\n";
            $rc = 1;
        }
        else {
            $typemap->{$ntype} = $type_primitive;
        }
    }
    dump_typemap($typemap, $fout);
    return $rc;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
