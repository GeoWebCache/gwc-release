#! /usr/bin/ruby

#
# GeoWebCache release script  run 'release.rb -h' for a description of the options
#
# Examples:
#
# For a RC release:
# release.rb --branch 1.8.x reset # Reset the local 1.8.x branch to match origin/1.8.x
# release.rb --new-branch 1.8.x --old-branch master --long-version 1.9-SNAPSHOT --short-version 1.9 --gt-version 15-SNAPSHOT branch # Create a 1.8.x branch off of master and update the build config on master to version 1.9.  Commits but does not push the changes.  Also allows the user to edit the release notes and then commits that seperately.
# release.rb --branch 1.8.x --long-version 1.8-RC1 --short-version 1.8 --gt-version 14-RC1 --type candidate update # update build config to release Release Candidate 1 of the 1.8 series
# release.rb --branch master --long-version 1.8-beta --type beta # Release beta for the 1.8 series
# For a normal release:
# release.rb --branch 1.8.x --long-version 1.8.0 --short-version 1.8 --gt-version 14.0 --type stable reset update build # sync to origin/1.8.x, update for a atable 1.8.0 release (including release notes)
# release.rb --branch 1.8.x --long-version 1.8.0 --short-version 1.8 --gt-version 14.0 --type stable build # build it
# release.rb --branch 1.8.x --long-version 1.8.0 --sf-user fred --type stable deploy # Upload the previously built artifacts to maven and sourceforge.  maven repo credentials are assumed to be in settings.xml and fred is a sourceforge user with permissions to update the GWC project.  fred is assumed to have set up SSH keys.
# release.rb --branch 1.8.x --long-version 1.8.0 --web-user fred --type stable web # Upload the previously built docs to the GWC website.  fred is a user with SSH access to wedge.boundlessgeo.com.  The updates will be placed in ~fred/web_tmp and can be copied into place with 'sudo cp -arf ~/web_temp/* /var/www/geowebcache.org/htdocs/'
# release.rb --branch 1.8.x --long-version 1.8.0 --release-commit 45811ed41ae57c89031a7e4a1c6d6c0cb63101db tag # tag the given commit as the release and then revert it (it should be the build config commit created by the 'update' command)
#

#
# Dependencies: GeoWebCache Build tools (Maven, Git, Java), make, Sphinx, Ruby, ruby-git, ruby-ssh, ruby-scp, xsddoc
#
# Install Ruby dependencies:
#   gem install bundle
#   bundle install
# 
# xsddoc:
#   <http://sourceforge.net/projects/xframe/files/xsddoc/>
#   Run 'dos2unix xsddoc' after downloading it if using a POSIX OS.  Place on the path or specifiy the location with --xsddoc-bin
#
   
require 'git'
require 'fileutils'
require 'logger'
require 'zip'
require 'pathname'
require 'net/ssh'
require 'net/scp'
require 'optparse'
require 'date'
require 'yaml'

$log = Logger.new($stdout)
$log.level = Logger::INFO
$log.progname = "GWC-Release"
$git_log = Logger.new($stdout)
$git_log.level = Logger::INFO
$log.progname = "git"
$ssh_log = Logger.new($stdout)
$ssh_log.level = Logger::WARN


RELEASE_TYPES=[
 :stable, # Release from the stable branch
 :maintenance, # Release from the maintenance branch
 :milestone, # Milestone from the master branch
 :beta, # Beta from the master branch
 :candidate, # Release candidate from the soon to be stable branch
]

def process_file(path, start=nil, stop=nil, backup=nil)
  puts path
  active = false
  active = true if start.nil?
  open(path, 'r') do |old_file|
    open("#{path}.new", 'w') do |new_file|
      old_file.each_line do |line|
        active = true if (not start.nil?) and start===line
        if active
          new_file.write yield line
        else
          new_file.write line
        end
        active = false if (not stop.nil?) and stop===line
      end
    end
  end
  #`meld #{path} #{path}.new`
  #FileUtils.rm "#{path}.new" 
  $log.debug("backup file #{backup.inspect}")
  FileUtils.cp("#{path}", "#{backup}") unless backup.nil?
  FileUtils.mv "#{path}.new", "#{path}"
end

def update_poms(gwc_version, gt_version)
  Dir.glob (File.join($dir, "geowebcache","**","pom.xml")) do |path| 
    process_file path do |line|
      line.sub! /<version>[^<]*<\/version><!-- GWC VERSION -->/, "<version>#{gwc_version}</version><!-- GWC VERSION -->"
      line.sub! /<gt.version>[^<]*<\/gt.version>/, "<gt.version>#{gt_version}</gt.version>"
      line.sub! /<finalName>geowebcache-[^<]*<\/finalName>/, "<finalName>geowebcache-#{gwc_version}</finalName>"
      line
    end
  end
end

def update_release(gwc_version)
  Dir.glob (File.join($dir, "geowebcache","release","{src,doc}.xml")) do |path| 
    process_file path do |line|
      line.sub /<!-- GWC VERSION -->[^<]*<!-- \/GWC VERSION -->/, "<!-- GWC VERSION -->#{gwc_version}<!-- /GWC VERSION -->"
    end
  end
end

def update_docs(long_version, short_version)
  process_file File.join($dir, "documentation","en","user","source","conf.py") do |line|
    line.sub! /^version = '[^']*'/, "version = '#{short_version}'"
    line.sub! /^release = '[^']*'/, "release = '#{long_version}'"
    line
  end
end

def update_config_default(gwc_version)
  path = File.join($dir, "geowebcache", "core","src","main","resources","geowebcache.xml") 
  replaced = []
  process_file path, /<gwcConfiguration/, />/, "#{path}.bak" do |line|
    line.gsub! /http:\/\/geowebcache.org\/schema\/([^"'\/\s]*)/ do |match| 
      replaced << $1
      "http://geowebcache.org/schema/#{gwc_version}"
    end
    line
  end 
  raise "Replaced versions not identical: #{replaced.inspect}" unless replaced.all? {|version| version == replaced[0]}

  if true
    suffix = replaced[0].gsub /\./, ""
    backup = File.join($dir, "geowebcache", "core","src","test","resources","org","geowebcache","config","geowebcache_#{suffix}.xml")
    FileUtils.mv "#{path}.bak", backup
  end

  replaced[0]
end

def update_config_schema(gwc_version)
  path = File.join($dir, "geowebcache", "core","src","main","resources","org","geowebcache","config","geowebcache.xsd") 
  replaced = []
  process_file path, /<xs:schema/, />/, "#{path}.bak" do |line|
    line.gsub! /http:\/\/geowebcache.org\/schema\/([^"'\/\s]*)/ do |match| 
      replaced << $1
      "http://geowebcache.org/schema/#{gwc_version}"
    end
    line.sub! /version=([\"\'])(.*?)\1/ do |match|
      replaced << $2
      "version=#{$1}#{gwc_version}#{$1}"
    end
    line
  end 

  raise "Replaced versions not identical: #{replaced.inspect}" unless replaced.all? {|version| version == replaced[0]}

  if true
    suffix = replaced[0].gsub /\./, ""
    backup = File.join($dir, "geowebcache", "core","src","main","resources","org","geowebcache","config","geowebcache_#{suffix}.xsd") 
    FileUtils.mv "#{path}.bak", backup
  end

  replaced[0]
end

def update_config(gwc_version)
  default_version = update_config_default(gwc_version)
  schema_version = update_config_schema(gwc_version)
  raise "Replaced versions not identical: geowebcache.xml #{default_version}, schema_versiongeowebcache.xsd #{schema_version}" unless default_version==schema_version
  default_version
end

def branch(new_version, new_gt_version, new_branch, old_branch, upstream_remote)
  mvn_gwc_version = "#{new_version}-SNAPSHOT"
  artifact_version = "#{new_version}-SNAPSHOT"
  mvn_gt_version = "#{new_gt_version}-SNAPSHOT"
  doc_version = "#{new_version}"
  doc_release = "#{new_version}.x"
  schema_version = "#{new_version}.0"
  
  $git.checkout(old_branch)
  branch_commit = $git.object('HEAD').sha

  old_schema_version = update_config(schema_version)

  $git.add("geowebcache/core")
  $git.commit_all("Retained #{old_schema_version} config for compatibility testing")
 
  update_poms(mvn_gwc_version, mvn_gt_version)
  update_release(artifact_version)
  update_docs(doc_release, doc_version)

  $git.commit_all("Updated version to #{artifact_version}")

  $git.push(upstream_remote, old_branch)

  $git.checkout(branch_commit)
  $git.checkout(new_branch, {:new_branch => true})
  $git.push(upstream_remote, new_branch)
end

def edit(file)
  raise "No editor set" if $options[:editor_bin].nil? or $options[:editor_bin].empty?
  system($options[:editor_bin], file)
end

def make(*params)
  args = [$options[:make_bin], "-C","#{File.join($dir,"documentation","en", "user")}", *params]
  $log.info args.join " "
  result = system(*args)
  raise "Make failed" unless result
end

def maven(*params)
  args = [$options[:maven_bin], "-f", "#{File.join($dir,"geowebcache","pom.xml")}", *params]
  $log.info args.join " "
  result = system(*args)
  raise "Maven build failed" unless result
end

def xsddoc(*params)
  args = [$options[:xsddoc_bin], *params]
  $log.info args.join " "
  result = system(*args)
  raise "xsddoc build failed" unless result
end

def update_for_release(long_version, short_version, gt_version, branch, upstream_remote)
  $log.info "Updating build config to release version #{long_version} from #{branch}"
  mvn_gwc_version = "#{long_version}"
  artifact_version = "#{long_version}"
  mvn_gt_version = "#{gt_version}"
  doc_version = "#{short_version}"
  doc_release = "#{long_version}"

  $git.checkout(branch)
  $git.remote(upstream_remote).fetch
  $git.reset_hard("#{upstream_remote}/#{branch}")
  
  release_notes = File.join($dir, "RELEASE_NOTES.txt")

  # Prepend template to the release notes
  open("#{release_notes}.new", 'w') do |file|
    header = "GeoWebCache #{long_version} (#{Date.today})"
    file.puts header
    file.puts "-"*header.length
    file.puts
    file.puts "<Release Description>"
    file.puts
    file.puts "Improvements:"
    file.puts "+++++++++++++"
    file.puts "- <New feature>"
    file.puts
    file.puts "Fixes:"
    file.puts "++++++"
    file.puts "- <Bug fix>"
    file.puts
    file.puts
    open("#{release_notes}", 'r') do |old_file|
      old_file.each_line do |line|
        file.puts line
      end
    end
  end
  # Let the user edit
  # TODO Make this amenable to running from Jenkins
  edit("#{release_notes}.new")

  # Replace the old notes and commit
  FileUtils.mv("#{release_notes}.new", release_notes)
  $git.commit_all("Updated release notes for #{artifact_version}")

  # Update POMs etc
  update_poms(mvn_gwc_version, mvn_gt_version)
  update_release(artifact_version)
  update_docs(doc_release, doc_version)

  $git.commit_all("Updated version to #{artifact_version}")

  release_commit = $git.object('HEAD').sha
  
  $log.info "Done updating build config.  Release commit is #{release_commit}"
  return release_commit;
end

def build_release(long_version, branch)
  $log.info "Building release #{long_version} from #{branch}"

  $git.checkout(branch)

  artifact_version = "#{long_version}"
 
  FileUtils.rm_rf $artifact_dir
  FileUtils.mkdir_p $artifact_dir

  $log.info "Building Documentation"
  make("clean", "html")
  
  $log.info "Building GeoWebCache"
  maven("clean", "install")
  
  $log.info "Building Release Artifacts"
  maven("assembly:attached")

  $log.info "Building Schema Documentation"
  xsddoc_artifact_dir = File.join($artifact_dir, "geowebcache-#{artifact_version}")
  xsddoc_dir = File.join(xsddoc_artifact_dir,"schema")
  xsddoc_zip = File.join($artifact_dir, "geowebcache-#{artifact_version}-xsddoc.zip")
  FileUtils.mkdir_p xsddoc_dir
  xsddoc "-o", "#{xsddoc_dir}", "-t", "GeoWebCache #{artifact_version} Configuration Schema", "#{$config_xsd}"
  $log.info "Building zip file #{xsddoc_zip} from directory #{xsddoc_artifact_dir}"
  Zip::ZipFile.open(xsddoc_zip, Zip::ZipFile::CREATE) do |zipfile|
    Dir[File.join(xsddoc_dir, '**', '**')].each do |file|
      path = Pathname.new(file)
      relative_path = Pathname.new($artifact_dir)
      $log.info "Adding #{$artifact_dir}"
      
      zipfile.add(path.relative_path_from(relative_path), file)
    end
  end
  $log.info "Removing directory #{xsddoc_artifact_dir}"  
  FileUtils.rm_rf xsddoc_artifact_dir
  $log.info "Done building release"
end

FRS_HOST = "frs.sourceforge.net"
FRS_SSH_PORT = 22

def deploy_release(long_version, type=:stable, sf_user, sf_password)
  $log.info "Deploying artifacts"

  $log.info "Deploying to maven repository"
  maven "deploy", "-DskipTests" # Tests ran while building, don't run them again
  
  $log.info "Deploying artifacts to Sourceforge"

  Net::SSH.start(FRS_HOST, sf_user, {:port => FRS_SSH_PORT, :logger => $ssh_log, :password => sf_password}) do |ssh|
    ssh.scp.upload! $artifact_dir, "/home/frs/project/geowebcache/geowebcache/#{long_version}", {:recursive => true}
  end

  $log.info "Done deploying artifacts" 
end

WEB_HOST = "wedge.boundlessgeo.com"
WEB_HOST_SSH_PORT = 7777

def deploy_release_web(version, type, wedge_user, wedge_password)
  $log.info "Updating geowebcache.org"

  Net::SSH.start(WEB_HOST, wedge_user, {:port => WEB_HOST_SSH_PORT, :logger => $ssh_log, :password => wedge_password}) do |ssh|
    config_schema_path = File.join($dir, "geowebcache", "core","src","main","resources","org","geowebcache","config","geowebcache.xsd") 
    # geowebcache/diskquota/core/src/main/resources/org/geowebcache/config/geowebcache-diskquota.xsd
    diskquota_schema_path = File.join($dir, "geowebcache", "diskquota", "core","src","main","resources","org","geowebcache","config","geowebcache-diskquota.xsd") 

    $log.info "Updating web page"

    
    docs_file = Tempfile.new("docs_index.html")
    docs_file.close
    
    ssh.scp.download! "/var/www/geowebcache.org/htdocs/docs/index.html", docs_file.path
    
    process_file( docs_file.path) do |line|
      case type
      when :stable
        line.sub! /<a href="latest\/">[^<]*<\/a>/, "<a href=\"latest/\">#{version}<\/a>"
      when :maintenance
        line.sub! /<a href="maintain\/">[^<]*<\/a>/, "<a href=\"maintain/\">#{version}<\/a>"
      when :milestone, :beta, :candidate
        line.sub! /<a href="latest\/">[^<]*<\/a>/, "<a href=\"latest/\">#{version}<\/a>"
      end
      line
    end

    process_file(docs_file.path, /<h2>Archived<\/h2>/, /<ul>/) do |line|
      line.sub! /<ul>/, "<ul>\n            <li><a href=\"#{version}\">#{version}</a></li>"
      line
    end
    
    $log.debug "Creating temp dirs"
    ssh.exec! "rm -rf web_temp"
    ssh.exec! "mkdir -p web_temp/docs"
    ssh.exec! "mkdir -p web_temp/schema/#{version}"
    ssh.exec! "mkdir -p web_temp/schema/docs"

    $log.debug "Uploading files"
    ssh.scp.upload! File.join($artifact_dir, "geowebcache-#{version}-xsddoc.zip"), "geowebcache-#{version}-xsddoc.zip"
    ssh.scp.upload! File.join($artifact_dir, "geowebcache-#{version}-doc.zip"), "geowebcache-#{version}-doc.zip"

    ssh.scp.upload! config_schema_path, "web_temp/schema/#{version}/geowebcache.xsd"
    ssh.scp.upload! diskquota_schema_path, "web_temp/schema/#{version}/geowebcache.xsd"

    ssh.scp.upload! docs_file.path, "web_temp/docs/index.html"
    
    $log.debug "Unzipping artifacts"
    ssh.exec! "unzip geowebcache-#{version}-xsddoc.zip"
    ssh.exec! "unzip geowebcache-#{version}-doc.zip"

    $log.debug "Moving artifacts contents into temp dir"
    ssh.exec! "mv geowebcache-#{version}/doc web_temp/docs/#{version}"
    ssh.exec! "mv geowebcache-#{version}/schema web_temp/schema/docs/#{version}"

    if true
      $log.debug "Deleting uploaded artifacts"
      ssh.exec! "rm -rf geowebcache-#{version}*"
    end

    case type
    when :stable
      ssh.exec! "ln -s #{version} web_temp/docs/current"
    when :maintenance
      ssh.exec! "ln -s #{version} web_temp/docs/maintain"
    when :milestone, :beta, :first_rc, :extra_rc
      ssh.exec! "ln -s #{version} web_temp/docs/latest"
    end

    $log.warn "Documentation artifacts uploaded to #{wedge_user}@#{WEB_HOST}:#{WEB_HOST_SSH_PORT} ~/web_temp/  Please log in, move them to /var/www/geowebcache.org/htdocs, and set the ownership/permissions to www-data www-data 755 to complete the update."
  end

  $log.info "Done updating geowebcache.org"
end

def reset (branches, upstream_remote)
  $log.info "Reseting branches to upstream"

  $git.remote(upstream_remote).fetch
  branches.each do |branch|
    $log.info "Reseting #{branch}"
    $git.checkout(branch)
    $git.reset_hard("#{upstream_remote}/#{branch}")
  end

  $log.info "Done reseting branches to upstream"
end

def tag_release(long_version, branch, upstream_remote, release_commit)
  $git.checkout(branch)
  $git.add_tag(long_version, release_commit)
  $git.revert(release_commit)
  $git.push(upstream_remote, branch, {:tags => true})
end

$dir = nil
$upstream_remote = nil
$type = nil

$long_version = nil
$short_version = nil
$gt_version = nil

$sf_user = nil
$sf_password = nil
$wedge_user = nil
$wedge_password = nil

$xsddoc_bin = nil
$maven_bin = nil
$make_bin = nil

$branch = nil
$old_branch = nil
$newbranch = nil

$cl_options = {}

LEVELS = {:fatal => Logger::FATAL, :error => Logger::ERROR, :warn => Logger::WARN, :info => Logger::INFO, :debug => Logger::DEBUG}

OptionParser.new do |opts|
  opts.banner = "Usage: release.rb [options] COMMAND [COMMAND ...]"

  opts.separator ""
  opts.separator "Commands:"
  opts.separator "        reset                        reset local branch and old-branch to match upstream."
  opts.separator "        branch                       Create a new branch and update the version numbers on the old one.  Pushes updates to GitHub."
  opts.separator "        update                       Update the versions for release."  
  opts.separator "        build                        Build the release artifacts."
  opts.separator "        deploy                       Upload to Maven and SourceForge"
  opts.separator "        tag                          Tag the release and revert to SNAPSHOT versions.  Pushes updates to GitHub."
  opts.separator "        web                          Update the geowebcache.org website"
  opts.separator ""

  opts.separator "Options:"
  opts.on("--type [TYPE]", RELEASE_TYPES,
          "The type of release being made (#{RELEASE_TYPES.join ", "})") do |type|
    $cl_options[:type] = type
  end
  opts.on("--user-defaults [DEFAULTS FILE]",
          "A yaml file containing default values for configuration") do |type|
    $cl_options[:user_defaults] = type
  end

  
  opts.separator ""
  opts.separator "Deployment Login Credentials:"
  opts.separator "   Credentials for deploying to the maven repository are assumed to be in settings.xml.  Git is assumed to have credentials to push to the GWC GitHub repository."
  opts.on("--sf-user [USERNAME]", "SourceForge username.  Required for deploy.") do |uname|
    $cl_options[:sf_user] = uname
  end
  opts.on("--sf-password [PASSWORD]", "SourceForge password.") do |pass|
    $cl_options[:sf_password] = pass
  end
  opts.on("--web-user [USERNAME]", "Web site username. Required for web deploy.") do |uname|
    $cl_options[:web_user] = uname
  end
  opts.on("--web-password [PASSWORD]", "Web site password.") do |pass|
    $cl_options[:web_password] = pass
  end

  opts.separator ""
  opts.separator "Executables:"
  opts.on("--maven-bin [PATH]", "Path of the maven executable") do |path|
    raise "#{path} is not an executable" unless File.executable? path
    $cl_options[:maven_bin] = path
  end
  opts.on("--make-bin [PATH]", "Path of the make executable") do |path|
    raise "#{path} is not an executable" unless File.executable? path
    $cl_options[:make_bin] = path
  end
  opts.on("--xsddoc-bin [PATH]", "Path of the xsddoc executable") do |path|
    raise "#{path} is not an executable" unless File.executable? path
    $cl_options[:xsddoc_bin] = path
  end
  opts.on("--editor-bin [PATH]", "Path of the text editor to use to edit the release notes") do |path|
    raise "#{path} is not an executable" unless File.executable? path
    $cl_options[:editor_bin] = path
  end

  opts.separator ""
  opts.separator "Version Numbers:"
  opts.on("-l", "--long-version [VERSION]", "Full version number (ie: 1.7.3, 1.8-beta, 1.9-SNAPSHOT)") do |version|
    $cl_options[:long_version] = version
  end
  opts.on("-s", "--short-version [VERSION]", "Major and minor versions only (ie: 1.7, 1.9)") do |version|
    $cl_options[:short_version] = version
  end
  opts.on("-g", "--gt-version [VERSION]", "GeoTools version (ie: 14.0, 15-SNAPSHOT)") do |version|
    $cl_options[:gt_version] = version
  end

  opts.separator ""
  opts.separator "Git:"
  opts.on("--new-branch [BRANCH]", "Branch to create.") do |branch|
    $cl_options[:new_branch] = branch
  end
  opts.on("--old-branch [BRANCH]", "Branch to fork from.") do |branch|
    $cl_options[:old_branch] = branch
  end
  opts.on("--branch [BRANCH]", "Branch to build from.") do |branch|
    $cl_options[:branch] = branch
  end
  opts.on("-d", "--directory DIRECTORY",
          "The root of the GeoWebCache source repository") do |dir|
    raise "#{dir} is not a directory" unless File.directory? dir
    $cl_options[:dir] = dir
  end
  opts.on("--upstream [REMOTE]", "The git remote for the official GeoWebCache repository") do |remote|
    $cl_options[:upstream_remote] = remote
  end
  opts.on("--release-commit [COMMIT]", "The commit to tag and roll back in the tag command.  Set automatically by the update command.") do |commit|
    $cl_options[:release_commit] = commit
  end

  opts.separator "Logging"
  opts.on("--log-level [LEVEL]", LEVELS.keys, "Logging level (#{LEVELS.keys.join ", "}).") do |level|
    $log.level = LEVELS[level]
  end
  opts.on("--git-log-level [LEVEL]", LEVELS.keys, "Logging level for Git (#{LEVELS.keys.join ", "}).") do |level|
    $git_log.level = LEVELS[level]
  end
  opts.on("--ssh-log-level [LEVEL]", LEVELS.keys, "Logging level for SSH (#{LEVELS.keys.join ", "}).") do |level|
    $ssh_log.level = LEVELS[level]
  end
  
end.parse!

$default_options = {
  :dir => Dir.pwd,
  :upstream_remote => "origin",
  :xsddoc_bin => "xsddoc",
  :maven_bin => "mvn",
  :make_bin => "make", 
  :editor_bin => ENV["EDITOR"]
}

user_defaults = if($cl_options[:user_defaults].nil?)
  begin
    YAML.load_file "user_defaults.yml"
  rescue Errno::ENOENT
    {}
  end
else
  YAML.load_file $cl_options[:user_defaults]
end.inject({}) do |hash, (k,v)|
  hash[k.to_sym] = v; 
  hash
end


def require_options(options, required_options)
  $log.debug "requiring #{options.inspect} includes #{required_options.inspect}"
  missing = required_options.select do |requirement|
    not options.has_key? requirement
  end
  raise "Missing options: #{missing.map{|option| "--#{option.to_s.gsub /_/, "-"}"}.join ', '}" unless missing.empty?
end

$options = $default_options.merge(user_defaults).merge($cl_options)

$log.info "Running with options: #{$options.inspect}"

$dir = $options[:dir]
$git = Git.open($options[:dir], :log => $git_log)

$artifact_dir = File.join($options[:dir],"geowebcache","target", "release")
$config_xsd = File.join($options[:dir], "geowebcache", "core","src","main","resources","org","geowebcache","config","geowebcache.xsd") 

raise "Do not combine branch with other commands except reset" if ARGV.include? "branch" and not ARGV.all? {|command| ["branch", "reset"].include? command}

ARGV.each do |command|
  case command

  when "reset" # Reset the branch
    to_reset = [:old_branch, :branch].map{|key| $options[key]}.uniq.compact
    raise "Must have set branch or old_branch to reset" if to_reset.empty?
    require_options($options, [:upstream_remote])
    params = [to_reset, $options[:upstream_remote]]
    puts "reset(#{params.map{|param| param.inspect}.join","})"
    reset(*params)

  when "branch" # Create a new branch and update the version numbers of the trunk

    raise "old-branch and new-branch can not be the same (#{$options[:old_branch]})" if $options[:old_branch]==$options[:new_branch] and not $options[:new_branch].nil?
    $log.debug "options: #{$options.inspect}"
    require_options($options, [:short_version, :gt_version, :new_branch, :old_branch, :upstream_remote])
    params =                  [:short_version, :gt_version, :new_branch, :old_branch, :upstream_remote].map{|key| $options[key]}
    puts "branch(#{params.map{|param| param.inspect}.join","})"
    branch(*params)

  when "update" # Update poms for commit
    require_options($options, [:long_version, :short_version, :gt_version, :branch, :upstream_remote])
    params =                  [:long_version, :short_version, :gt_version, :branch, :upstream_remote].map{|key| $options[key]}
    puts "update_for_release(#{params.map{|param| param.inspect}.join","})"

    commit = update_for_release(*params)
    $log.warn "Release commit was already set to #{$options[:release_commit]}, replacing with #{commmit}" unless $options[:release_commit].nil?
    $options[:release_commit] = commit
 
  when "build" # Build artifacts
    require_options($options, [:long_version, :branch])
    params =                  [:long_version, :branch].map{|key| $options[key]}
    puts "build_release(#{params.map{|param| param.inspect}.join","})"
    build_release(*params)

  when "deploy" # Deploy artifacts
    require_options($options, [:long_version, :branch, :sf_user])
    params =                  [:long_version, :branch, :sf_user, :sf_password].map{|key| $options[key]}
    puts "deploy_release(#{params.map{|param| param.inspect}.join","})"
    deploy_release(*params)

  when "tag" # Tag the release, revert changes, and push to repository
    require_options($options, [:long_version, :branch, :upstream_remote, :release_commit])
    params =                  [:long_version, :branch, :upstream_remote, :release_commit].map{|key| $options[key]}
    puts "tag_release(#{params.map{|param| param.inspect}.join","})"
    tag_release(*params)

  when "web"
    require_options($options, [:long_version, :type, :web_user])
    params =                  [:long_version, :type, :web_user, :web_password].map{|key| $options[key]}
    puts "web(#{params.map{|param| param.inspect}.join","})"
    deploy_release_web(*params)

  else
    raise "Unknown command '#{command}'"

  end
end
