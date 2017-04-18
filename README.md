# makeEPUBfromCBZs
If you have a bunch of CBZ files in a format:
  SomeSeries/chapter1.cbz
  SomeSeries/chapter2.cbz
  ...etc
This tool (with a help of small text file) with combine all CBZs into one EPUB file.
The usage:
  perl makeEpubFromCBZs.pl book_description.txt
where book_description.txt is file with format:
  name=Name of the Manga
  author=Name of Author
  intro=Some description for that manga
  chapters=C:\ComicBooks\Folder\
  cover=chapter1.cbz/003.jpg
If 'cover' is ommited - the first image from the first chapter would be used.
