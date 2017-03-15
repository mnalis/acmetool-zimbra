# acmetool-zimbra
Let's Encrypt certificates for Zimbra using acmetool in user (non-root) mode
* assumes zimbra 8.7.x (tested on 8.7.4 on Ubuntu)

* requirement - zimbra setup not to listen on port 80 (so apache can listen there)
~~~
/opt/zimbra/bin/zmprov gs $(/opt/zimbra/bin/zmhostname) zimbraReverseProxyMailMode | grep Mode
~~~
should be **https** and not **redirect**
Zimbra should not use separate IP/port/certificate for each domain (but all of them using same IP/port/certificate)

* requirement - working acmetool as user acme, for example:
~~~
apt-get install acmetool make ca-certificates apache2
adduser --system --group --home /var/lib/acme --disabled-password --disabled-login acme
perl -p -i.bak -e 's{^exit 0}{# for Lets encypt acmetool\ninstall -d -o acme -g acme -m 0755 /var/run/acme\n\nexit 0}' /etc/rc.local
install -d -o acme -g acme -m 0755 /var/run/acme

sudo -u acme acmetool quickstart 
# use webproxy mode with /var/run/acme/acme-challenge as webroot path, and enable cron updates

printf 'Alias "/.well-known/acme-challenge/" "/var/run/acme/acme-challenge/"
<Directory "/var/run/acme/acme-challenge">
\tAllowOverride None
\tOptions None
\tRequire all granted
</Directory>\n' >> /etc/apache2/conf-available/letsencrypt.conf

a2enconf letsencrypt
service apache2 reload
~~~



* install:
~~~
cd /opt
git clone https://github.com/mnalis/acmetool-zimbra.git zsc-acmetool
~~~

* usage:
~~~
cd /opt/zsc-acmetool && make
~~~
it will detect all the hostnames you use (you can check in all_domains.txt file and ) and request let's encrypt certificates

* auto-renew
~~~
cp example.cron /etc/cron.daily/zimbra-acmetool
~~~
