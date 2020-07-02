# Harbour_FastCGI
Framework to create FastCGI apps in Harbour

For detailed instructions read article at: https://harbour.wiki/index.asp?page=PublicArticles&mode=show&id=190207001538&sig=3331951908

Currently FastCGI programs can be compiled with MSVC64 or Mingw64 under Microsoft Windows.

When editing any Apache configuration file under MS Windows, ensure all reference to drive letters are upper case.

Upcoming version runs on Ubuntu / Lubuntu with Lighttpd and has all the same features as the MS Windows version. A "Hello World" web page can be generated more than 2000 per second on a single i7 core standard laptop (compared to 15 CGI under MS Windows).
