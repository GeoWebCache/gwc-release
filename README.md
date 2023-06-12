This ruby script automates the release of GeoWebCache.

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
   
Before starting a release
-------------------------

If running on a non-Windows platform after installing xssdoc:

````
dos2unix xsddoc
````

Copy the ``release.rb`` in the root of your GeoWebCache installation and make sure the "EDITOR" variable is set, e.g.

````
echo $EDITOR
# if empty then
export EDITOR=vi
````

Also make sure xsddoc in in the path.


Releasing a stable release
--------------------------

Assuming one wants to release a GWC 1.9.3, which depends on GeoTools 15.4, then run the following commands:

````
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable reset update 
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable build
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --sf-user aaime deploy
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --release-commit <versionCommitId> tag
````

where ``versionCommitId`` is the commit automatically created by the update command, that switched all the pom files to release 1.15.3 (that needs to be tagged, and then reverted for the 1.15.x branch).

As an optional command for those having access to the server running geowebcache.org, the web site can be updated using:

````
ruby release.rb --branch 1.9.x --long-version 1.9.3 --short-version 1.9 --gt-version 15.4 --type stable --web-user <serverUserName> web
```` 


Creating a new branch
---------------------

Same as above, but with these instructions:

````
ruby release.rb --branch main reset
ruby release.rb --new-branch 1.21.x --old-branch main --long-version 1.21-SNAPSHOT --short-version 1.21 --gt-version 27-SNAPSHOT branch
ruby release.rb --branch 1.21.x --long-version 1.21-RC --short-version 1.21 --gt-version 21-RC --type candidate update
ruby release.rb --branch 1.21.x --long-version 1.21-RC --short-version 1.21 --gt-version 21-RC --type candidate build
ruby release.rb --branch 1.21.x --long-version 1.21-RC --short-version 1.21 --gt-version 21-RC --type candidate --sf-user aaime deploy
ruby release.rb --branch 1.21.x --long-version 1.21-RC --release-commit 56389371f6d92b5493100b1c519f05a5037bc1b0 tag
````

To update existing `main` after creation of a new branch:
```
ruby release.rb --branch main --long-version 1.22-SNAPSHOT --short-version 1.22 --gt-version 28-SNAPSHOT --type stable update
```
