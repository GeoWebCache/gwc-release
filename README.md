# GWC release docker image

The ruby script used below for the automated release of GeoWebCache, relied on an old setup that was difficult to reproduce.  This resulted in a small number of volunteers being able to release GWC, until Andrea created this docker image to ease the pain.

## Instructions for use

Check out the `docker` branch from https://github.com/aaime/gwc-release/tree/docker and enter this directory.

Build the image from the Dockerfile with:

`docker build -t gwc_release:0.1 .`

Run the image, passing in Git credentials as environment variables:

`docker run -it -v d:/tmp/m2:/root/.m2 -e GIT_USERNAME="user" -e GIT_EMAIL="someone@somewhere.insummertime" gwc_release:0.1`

Note that the maven repository /root/.m2 is mapped to the host's d:/tmp/m2 for persistence.

Once started, one has to hand-edit the /root/.m2/settings.xml file to add the repo.osgeo.org credentials (OSGeo login, needs nexus permissions suitable for release: geoserver - geowebcache uses geoserver repo) (maybe we could make this also as part of the docker run command above?).

Finally, in order to tag at the end, one needs to create a GitHub personal access token that will be used as the password for that step (go to your user settings, developer settings (right at the bottom, left), and create a personal access token). This could also be avoided by replacing with a step to copy over the identification certificate, and then checkout GWC using the ssh URL.

### Now that docker is set up, you're ready to continue with the original GWC release instructions below (skipping Installation):

This ruby script allows to automate the release of GeoWebCache.

Requirements
------------

* Commit access to the https://github.com/GeoWebCache repo (team-geowebcache)
* GitHub personal access token
* repo.osgeo.org credentials (OSGeo login) with nexus permissions suitable for release: geoserver
* SourceForge credentials

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

If running on a non Windows platform after installing xssdoc:

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


Releasing a stable/maintenance release
--------------------------------------

First, manually check the GitHub commit history e.g. https://github.com/GeoWebCache/geowebcache/commits/1.26.x/ for the Improvements or Fixes to go into the Release notes.

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

This is applicable when preparing the Release Candidate or .0 Initial release

Instead of the 4 ruby commands above, use these commands:

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
