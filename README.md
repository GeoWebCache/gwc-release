This ruby script allows to automate the release of GeoWebCache.

Installation
------------

Script dependencies to install manually and put in the path:
* GeoWebCache Build tools (Maven, Git, Java)
* make
* Sphinx
* Ruby
* xsddoc

Once Ruby is installed the library dependencies can be installed by running:

````
gem install bundle
bundle install
````
   
If running on a non Windows platform after installing xssdoc:

````
dos2unix xsddoc
````

Finally, copy the ``release.rb`` in the root of your GeoWebCache installation and make sure the "EDITOR" variable is set, e.g.

````
echo $EDITOR
# if empty then
export EDITOR=vi
````

Releasing a stable release
--------------------------

Assuming one wants to release a GWC 1.9.3, which depends on GeoToools 15.4, then run the following commands:

````
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable reset update 
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable build
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --sf-user <theUser> deploy
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --release-commit <versionCommitId> tag
````

where ``versionCommitId`` is the commit automatically created by the update command, that switched all the pom files to release 1.9.3 (that needs to be tagged, and then reverted for the 1.9.x branch).

As an optional command for those having access to the server running geowebcache.org, the web site can be updated using:

````
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --web-user <serverUserName> web
```` 


Creating a new branch
---------------------

TBD, check the commends in the header of release.rb