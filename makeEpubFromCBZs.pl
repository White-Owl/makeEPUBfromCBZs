#!/usr/bin/perl
use strict;
use warnings;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IO::File;
use IO::Dir;
use XML::Writer;

my $book_description = $ARGV[0];
my ($book_name, $book_author, $cover_file, $source_folder, $introduction);
open(F, "<$book_description") || die;
while(<F>) {
	$book_name = $1 if(/^name=(.+)/);
	$book_author = $1 if(/^author=(.+)/);
	$cover_file = $1 if(/^cover=(.+)/);
	$source_folder = $1 if(/^chapters=(.+)/);
	$introduction = $1 if(/^intro=(.+)/);
}
close(F);
my $epub_file_name = "$book_author, $book_name.epub";
unlink($epub_file_name);

my $book = Archive::Zip->new();
####################################################
# create a basic necessary info
my $string_member = $book->addString( 'application/epub+zip', 'mimetype' );
$string_member->desiredCompressionMethod( COMPRESSION_STORED );
my $dir_META_INF = $book->addDirectory( 'META-INF/' );
$string_member = $book->addString( <<EOT, 'META-INF/container.xml' );
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
   </rootfiles>
</container>
EOT
$string_member->desiredCompressionMethod( COMPRESSION_DEFLATED );


####################################################
# Read list of files in the source folder and construct chapter pages with a TOC
my $source_dir = IO::Dir->new($source_folder);
my $chapter_counter = 0;
my $toc_writer = XML::Writer->new(OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT=>2);
$toc_writer->xmlDecl("UTF-8");
$toc_writer->doctype('ncx', "-//NISO//DTD ncx 2005-1//EN", 'http://www.daisy.org/z3986/2005/ncx-2005-1.dtd');
$toc_writer->startTag('ncx', 'xmlns'=>"http://www.daisy.org/z3986/2005/ncx/", 'version'=>"2005-1");
$toc_writer->startTag('docTitle');
$toc_writer->dataElement('text'=>$book_name);
$toc_writer->endTag('docTitle');
$toc_writer->startTag('navMap');

my $content_writer = XML::Writer->new(OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT=>2);
$content_writer->xmlDecl("UTF-8", "yes");
$content_writer->startTag('package', 'xmlns'=>"http://www.idpf.org/2007/opf", 'unique-identifier'=>"unknown", 'version'=>"2.0");
$content_writer->startTag('metadata', 'xmlns:dc'=>"http://purl.org/dc/elements/1.1/", 'xmlns:opf'=>"http://www.idpf.org/2007/opf");
$content_writer->dataElement('dc:title', $book_name);
$content_writer->dataElement('dc:creator', $book_author, 'opf:file-as'=>$book_author, 'opf:role'=>"aut");
$content_writer->emptyTag('meta', 'name'=>"cover", 'content'=>"cover");
$content_writer->endTag('metadata');
$content_writer->startTag('manifest');
$content_writer->emptyTag('item', 'href'=>"cover.jpeg", 'id'=>"cover", 'media-type'=>"image/jpeg");
$content_writer->emptyTag('item', 'href'=>"index.html", 'id'=>"index", 'media-type'=>"application/xhtml+xml");
#$content_writer->emptyTag('item', 'href'=>"titlepage.html", 'id'=>"titlepage", 'media-type'=>"application/xhtml+xml");
$content_writer->emptyTag('item', 'href'=>"toc.ncx", 'id'=>"ncx", 'media-type'=>"application/x-dtbncx+xml");



my $index_text = "<html><head><title>$book_name</title></head><body>\n";
while (defined($_ = $source_dir->read)) {
	if(/(.+)\.cbz$/) {
		$chapter_counter++;
		my $chapter_title=$1;
		my $chapter_folder_name = sprintf("%04d", $chapter_counter);
		my $chapter_cbz = Archive::Zip->new("$source_folder/$chapter_title.cbz");
		$book->addDirectory($chapter_folder_name);
		my @images = $chapter_cbz->memberNames();
		my $image_counter = 0;
		print "$chapter_title\n";
		foreach my $img(sort @images) {
			$cover_file = "$chapter_title.cbz/$img" if(! $cover_file);
			$image_counter++;
			$index_text .= "<p id=\"img${chapter_folder_name}x$image_counter\"><img src=\"$chapter_folder_name/$img\">\n";
			my $data = $chapter_cbz->contents($img);
			$book->addString($data, "$chapter_folder_name/$img", COMPRESSION_LEVEL_BEST_COMPRESSION);
			$img =~ /\.(.+)$/;
			my $img_type='jpeg';
			$img_type = 'png' if($1 eq 'png');
			$content_writer->emptyTag('item', 'href'=>"$chapter_folder_name/$img", 'id'=>"img${chapter_counter}x${image_counter}", 'media-type'=>"image/$img_type");

			if($image_counter==1) {
				$toc_writer->startTag('navPoint', 'class'=>"chapter", 'id'=>"num_$chapter_counter", 'playOrder'=>"$chapter_counter");
				$toc_writer->startTag('navLabel');
				$toc_writer->dataElement('text'=>$chapter_title);
				$toc_writer->endTag('navLabel');
				$toc_writer->emptyTag('content', 'src'=>"index.html#img${chapter_folder_name}x1");
				$toc_writer->endTag('navPoint');
			}
		}
	}
}
undef $source_dir;
$index_text .="</body></html>";
$toc_writer->endTag('navMap');
$toc_writer->endTag('ncx');
$toc_writer->end();




$content_writer->endTag('manifest');
$content_writer->startTag('spine', 'toc'=>"ncx");
$content_writer->emptyTag('itemref', 'idref'=>"cover");
$content_writer->emptyTag('itemref', 'idref'=>"index");
$content_writer->endTag('spine');
$content_writer->startTag('guide');
$content_writer->emptyTag('reference', 'href'=>"cover.jpg", 'title'=>"Cover", 'type'=>"cover");
#$content_writer->emptyTag('reference', 'href'=>"TOC.html", 'title'=>"Table Of Contents", 'type'=>"toc");
#$content_writer->emptyTag('reference', 'href'=>"introduction.html", 'title'=>"Text", 'type'=>"text");
$content_writer->endTag('guide');
$content_writer->endTag('package');
$content_writer->end();

$string_member = $book->addString( $index_text, 'index.html' );
$string_member->desiredCompressionMethod( COMPRESSION_DEFLATED );
$string_member = $book->addString( $content_writer->to_string(), 'content.opf' );
$string_member->desiredCompressionMethod( COMPRESSION_DEFLATED );
$string_member = $book->addString( $toc_writer->to_string(), 'toc.ncx' );
$string_member->desiredCompressionMethod( COMPRESSION_DEFLATED );

$cover_file =~ /(.+)\/(.+)/;
my $chapter_cbz = Archive::Zip->new("$source_folder/$1");
my $data = $chapter_cbz->contents($2);
$book->addString($data, "cover.jpeg", COMPRESSION_LEVEL_BEST_COMPRESSION);


# Save the Zip file
unless ( $book->writeToFileNamed($epub_file_name) == AZ_OK ) {
    die 'write error';
}