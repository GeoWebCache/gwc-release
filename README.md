Requirements
------------

* Commit access to the https://github.com/GeoWebCache repo (team-geowebcache)
* GitHub personal access token
* repo.osgeo.org credentials (OSGeo login) with nexus permissions suitable for release: geoserver
* SourceForge credentials

Installation
------------

Install and put in the path:

* Git
* Java 17
* Maven
* make and Sphinx
* Ruby

Install the Ruby dependencies from this directory:

````
gem install bundler
bundle install
````

Add the repo.osgeo.org credentials to ``~/.m2/settings.xml`` (see ``settings.xml`` for the ``nexus`` server entry); geowebcache is deployed to the geoserver repository.

Copy ``release.rb`` into the root of your GeoWebCache checkout and make sure ``EDITOR`` is set, e.g.

````
export EDITOR=vi
````

To tag at the end, use a GitHub personal access token as the password, or check out GeoWebCache using the ssh URL.

Releasing a stable release
--------------------------

First, manually check the GitHub commit history e.g. https://github.com/GeoWebCache/geowebcache/commits/2.0.x/ for the Improvements or Fixes to go into the Release notes.

Assuming one wants to release a GWC 2.0.1, which depends on GeoTools 35.1, then run the following commands:

````
ruby release.rb --branch 2.0.x --long-version 2.0.1 --short-version 2.0 --gt-version 35.1 --type stable reset update 
ruby release.rb --branch 2.0.x --long-version 2.0.1 --short-version 2.0 --gt-version 35.1 --type stable build
ruby release.rb --branch 2.0.x --long-version 2.0.1 --short-version 2.0 --gt-version 35.1 --type stable deploy
ruby release.rb --branch 2.0.x --long-version 2.0.1 --short-version 2.0 --gt-version 35.1 --type stable --sf-user jive upload
ruby release.rb --branch 2.0.x --long-version 2.0.1 --short-version 2.0 --gt-version 35.1 --type stable --release-commit <versionCommitId> tag
````

Where ``versionCommitId`` is the commit automatically created by the update command (step 1), that switched all the pom files to release 2.0.1 (that needs to be tagged, and then reverted for the 2.0.x branch).

Releasing a maintenance release
------------------------------

(The only difference is `--type maintenance`)

First, manually check the GitHub commit history e.g. https://github.com/GeoWebCache/geowebcache/commits/1.28.x/ for the Improvements or Fixes to go into the Release notes.

Assuming one wants to release a GWC 1.28.1, which depends on GeoTools 34.1, then run the following commands:

````
ruby release.rb --branch 1.28.x --long-version 1.28.1 --short-version 1.28 --gt-version 34.1 --type maintenance reset update 
ruby release.rb --branch 1.28.x --long-version 1.28.1 --short-version 1.28 --gt-version 34.1 --type maintenance build
ruby release.rb --branch 1.28.x --long-version 1.28.1 --short-version 1.28 --gt-version 34.1 --type maintenance deploy
ruby release.rb --branch 1.28.x --long-version 1.28.1 --short-version 1.28 --gt-version 34.1 --type maintenance --sf-user jive upload
ruby release.rb --branch 1.28.x --long-version 1.28.1 --short-version 1.28 --gt-version 34.1 --type maintenance --release-commit <versionCommitId> tag
````

Where ``versionCommitId`` is the commit automatically created by the update command (step 1), that switched all the pom files to release 1.28.1 (that needs to be tagged, and then reverted for the 1.28.x branch).


Creating a new branch
---------------------

This is applicable when preparing the initial `.0` stable release of a new branch, or use `--type candidate` for a release candidate:

Before starting the release, use the following commands to setup a new branch:

````
ruby release.rb --branch main reset
ruby release.rb --new-branch 2.1.x --old-branch main --long-version 2.1-SNAPSHOT --short-version 2.1 --gt-version 36-SNAPSHOT branch
```

And then follow the usual release procedure from the new branch:
```
ruby release.rb --branch 2.1.x --long-version 2.1.0 --short-version 2.1 --gt-version 26.0 --type stable update
ruby release.rb --branch 2.1.x --long-version 2.1.0 --short-version 2.1 --gt-version 26.0 --type stable build
ruby release.rb --branch 2.1.x --long-version 2.1.0 --short-version 2.1 --gt-version 26.0 --type stable deploy
ruby release.rb --branch 2.1.x --long-version 2.1.0 --short-version 2.1 --gt-version 26.0 --type stable --sf-user aaime upload
ruby release.rb --branch 2.1.x --long-version 2.1.0 --release-commit 56389371f6d92b5493100b1c519f05a5037bc1b0 tag
````

After releasing from the new branch, update the existing `main` branch to the new SNAPSHOT version:
```
ruby release.rb --branch main --long-version 2.2-SNAPSHOT --short-version 2.2 --gt-version 37-SNAPSHOT --type stable update
```

# Create a GitHub release

Finally, open https://github.com/GeoWebCache/geowebcache/tags and click Create Release, documenting all the changes
