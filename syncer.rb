#!/usr/bin/env ruby
require 'net/ftp'
require 'fileutils'
require 'find'

## Syncer simply copies a directory from or to a remote location
## either by using _ftp_ or _scp_  and creates a local git repo if
## wished; 
## You need to give a config file with the following key = value options:
## * ip = remote_host
## * user = user_name
## * pw = secret_password
## * remote_dir = htdocs/www_site
## * local_dir = local_directory
## * method = [ ftp | scp ]
## * git = [ true | false ]
## * port = port_number (optional)


class Syncer

  attr_accessor :ip, :method, :user , :pw, :remote_dir, :local_dir, :port, :git
  
  def initialize (config_file)
  
    ## checking start conditions
    config_exists?(config_file)

    ## vars
    conf = r_config(config_file)
    
    self.ip = conf["ip"]
    self.method = conf["method"]
    self.user = conf["user"]
    self.pw = conf["pw"]
    self.remote_dir = conf["remote_dir"]

    ## set dirs
    unless conf["local_dir"] == nil
      self.local_dir = conf["local_dir"]
    else
      self.local_dir = conf["remote_dir"]
    end

    ## set port
    if conf["port"] != nil
      self.port = conf["port"]
    elsif self.method == "ftp"
      self.port = 21
    elsif self.method == "scp"
      self.port = 22
    end
  
    ## create a git repo?
    if (conf.fetch("git") == "true") then self.git = true end
    
    ## action!
    action()

  end

  def download()
    puts "\nFetching files from #{self.ip}"
    begin
      
      Dir.mkdir(self.local_dir)

      if self.method == "scp" then
        puts "scp -r -P #{self.port} #{self.user}@#{self.ip}:#{self.remote_dir} #{self.local_dir}"
        `scp -r -P #{self.port} #{self.user}@#{self.ip}:#{self.remote_dir} #{self.local_dir}`
      elsif self.method == "ftp" then
        ## using wget for FTP Download
        puts "wget -rnH --ftp-user=#{self.user} --ftp-password=#{self.pw} ftp://#{self.ip}/#{self.remote_dir}/ "
        `wget -rnH --ftp-user=#{self.user} --ftp-password=#{self.pw} ftp://#{self.ip}/#{self.remote_dir}/ `
      end
      puts " ---------------------"
      puts "Downloaded files via #{self.method}. Finished!"
      puts " ---------------------"
      ## create Git Repo
      if self.git == true then git_init(self.local_dir) end
    rescue => e
      error(e)
    end
  end

  def upload()
    begin
      if self.method == "scp" then
        `scp -r -P #{self.port} #{self.local_dir} #{self.user}@#{self.ip}:#{self.remote_dir} `
      elsif self.method == "ftp" then
        ftp = Net::FTP.new(self.ip)
        ftp.login(user = self.user, passwd = self.pw)
        ftp.chdir(self.remote_dir)
        basedir = "/" + self.remote_dir
        ## get all directroy entries
        ary = collect_dir_items()
        ## create remote directories
        ary[0].each do |dir|
          ftp.mkdir(dir)
        end
        ## upload files recursively where they belong
        ary[1].each do |file|
          ftp.chdir(File.dirname(file))
          ftp.put(file)
          puts file
          ftp.chdir(basedir)
        end
        ftp.close
      end
    rescue => e
      puts e
    end
  end

  protected

  ## Collect all files and Dirs into a handy Array of Arrays
  def collect_dir_items()
    dirs=[]
    files=[]
    Find.find(".") do |ff|
      if FileTest.directory?(ff)
        ## select only "real" dirs
        if ff =~ /^.\/.\w/
          dirs.push ff
        end
      else
        files.push ff
      end
    end
    ## push everything into an Array
    ## to keep order
    ary = []
    ary.push dirs
    ary.push files
    
    return ary

  end

  ## Create basic git Repo as initial commit
  def git_init(dir)
    
    puts "Creating Git Repo"

    FileUtils.cd(dir) do
      unless File.exist?('.git')
        `git init`
        `git add .`
        `git commit -am "Initial Commit"`
      end
    end
  end

  ## read config File to Hash
  def r_config(conf)
    
    h = Hash.new
    
    begin
      File.open(conf, "r") do |f|
        f.each_line do |line|
          ## ignore comments in config File
          unless line =~ /^#/
            if line.include? '='
              a = line.split("=")
              h.store(a[0].chomp.strip, a[1].chomp.strip)
            end
          end
        end
      end

      search_missing_params(h)

      ## Return Hash with config vars
      return h

    rescue => e
      puts "An error occured whilst parsing the config file =>" + e
      puts "Please check yur config file!"
    end
  end
  
  ## checking for missing settings in config file 
  def search_missing_params(h)
      
      settings = Array.new
      h.each {|key,val| settings.push(key)}
      
      ['user','pw','remote_dir','ip','method'].each do |elem|
        unless settings.include?(elem)
            puts "Missings Setting in config file: " + elem + "\nPlease edit your config File. Exiting...."
            exit
        end
      end
  end

  ## generic error text
  def error(e)
    puts "Bei der Verbindung ist ein Fehler aufgetreten."
    puts "Ausgabe des Remote Servers:", e
  end

  ## Check wether the config file given is existent
  def config_exists?(config_file)
      unless File.exist?(config_file)
        puts "Config file #{config_file} not found .....\nExiting....."
        exit
      end
  end

  ## Check command Line Parameters to know what to do
  def action()
    case $*[0]
      when "upload" , "u"
        upload()
      when "download" , "d"
        download()
      else
        puts "Valid actions are :\nupload OR u\ndownload OR d\nExiting ....."
        exit
    end
  end
end

t = Syncer.new('config.txt')
