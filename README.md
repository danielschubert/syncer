# syncer
Simple script to sync remote dirs via SCP or FTP. Written in Ruby.

Syncer simply copies a directory from or to a remote location
either by using _ftp_ or _scp_  and creates a local git repo if
wished; 
You need to give a config file with the following key = value options:
- ip = remote_host
- user = user_name
- pw = secret_password
- remote_dir = htdocs/www_site
- local_dir = local_directory
- method = [ ftp | scp ]
- git = [ true | false ]
- port = port_number (optional)
