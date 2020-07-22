# These are the steps taken to install, deploy and secure
# xibo cms on our forge server running Ubuntu 20.04 LTS
# finished on 21st july 2020

# please run these commands as root.
sudo su

# Step 1 is to install docker, using these commands

# install a few prerequisite packages which lets, apt use packages over HTTPS:
apt-get install apt-transport-https ca-certificates curl software-properties-common

# Then add the GPG key for the official Docker repository to your system:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add the Docker repository to APT sources:
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update Packages database
apt-get update

# Finally install Docker
apt-get install docker-ce

# Step 2 is to install docker-compose using these commands

# Downloads release 1.24.1 and save exec file at /usr/..., which makes this software accessible as docker-compose
curl -L https://github.com/docker/compose/releases/download/1.24.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

# Set the correct permissions so that the docker-compose command is executable
chmod +x /usr/local/bin/docker-compose

# Step 3: Install the Xibo CMS

# Make new directory for xibo and cd into it
mkdir /opt/xibo &&  cd /opt/xibo

# Download the latest stable version of the CMS in gzipped format (tar file)
wget -O xibo-docker.tar.gz https://xibo.org.uk/api/downloads/cms

# Unzip Xibo tar file and preserve folder structure
tar --strip-components=1 -zxvf xibo-docker.tar.gz


# Step 4: Create a config.env file, and set a  MYSQL_PASSWORD value

# Create config.env file
cp config.env.template config.env

# Open config.env file
nano config.env

# Scroll down to the line written MYSQL_PASSWORD=, 
# and set a randomly generated  16 character alpanumeric password, no symbols/special characters
# SAVE CHANGES

# Bring up the CMS, 
docker-compose up -d

 # if it brings an error, it means something is running on port 80:
 # View it with  [OPTIONAL]
 lsof -nP -iTCP -sTCP:LISTEN

# kill whatever is running on port 80, using it's pid number
kill -9 PID

# After viewing it, and making sure it is working, kill the container 
docker-compose down


# Step 5: Adding ssl support using apache

# We will be moving xibo to a custom port
# create a custom.ports.yml file
cp cms_custom-ports.yml.template cms_custom-ports.yml

# Open the file
nano cms_custom-ports.yml

# There are two headings called " ports"

# The first says  ports:
                 # - "65500:9505"
# change it to:
    #ports:
     #            - "9505:9505"


# The second says  ports:
                # - "65501:80"
# Change it to ports:
                 # - "127.0.0.1:8080:80"        
 # SAVE CHANGES

# Now the CMS WILL RUN ON PORT 9505, AND ONLY BE AVAILABLE ON PORT 80 ON A LOOPBACK INERFACE


# Now let's complete the loopback interface (reverse proxy) using an apache server 



# Now let's secure the container using an apache se

# Install apache
apt-get install apache2

# Enable the main proxy module Apache module for redirecting connections
a2enmod proxy

# Add support for proxying HTTP connections.
a2enmod proxy_http

# Add support that can replace, merge or remove HTTP response headers
a2enmod headers

# Edit the default apache config file to create a reverse proxy to our container:
# IT IS MORE IDEAL TO CREATE A SEPERATE VHOST FILE,
# ESPECIALLY IF WE WANT TO HOST MORE APPS AND CONTAINERS, BUT WE WILL USE THIS FOR THE MEAN TIME

nano /etc/apache2/sites-available/000-default.conf

# Edit it so it reads thus (just add the last 5 directives/lines of code)


# <VirtualHost *:80>

#         ServerAdmin webmaster@localhost
#         DocumentRoot /var/www/html

#         ErrorLog ${APACHE_LOG_DIR}/error.log
#         CustomLog ${APACHE_LOG_DIR}/access.log combined

#         ProxyPreserveHost On
#         RequestHeader set X-Forwarded-Proto expr=%{REQUEST_SCHEME}
#         
#         ProxyPass / http://127.0.0.1:8080/
#         ProxyPassReverse / http://127.0.0.1:8080/

# </VirtualHost>

# Restart apache
service apache2 restart

# Install certbort for ssl certificates

# update repository list
apt-get update

# install software-properties-common (might be installed already, no problem)
apt-get install software-properties-common

# install universe (might be installed already, no problem)
add-apt-repository universe

# update repository list
apt-get update

# install certbot for apache
apt-get install certbot python3-certbot-apache
# Follow the prompts, but do not accept the option 
# to automatically redirect requests to https connections (We will do this from the cms)

certbot --apache -d site-address -d www.site-address

# Test if automatic renewal is running properly
certbot renew --dry-run
# if it brings no errors, then everything is fine

# check status of certbot internal timer that will automatically renew your certificate
systemctl status certbot.timer

# if it doesn't show enabled (green)
systemctl start certbot.timer

# finally bring up the container with:

docker-compose -f cms_custom-ports.yml up -d

# visit the site