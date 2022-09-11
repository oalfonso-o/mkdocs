# Mail Server with Postfix and Dovecot

This post explains how to setup a [Postfix](https://www.postfix.org/) [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) server and a [Dovecot](https://www.dovecot.org/) [IMAP](https://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) server for personal use.
For entreprise I recommend selecting a trusted vendor.

This post will go through:

- the basics of email
- the configuration for Postfix
- the configuration for Dovecot and the auth
- the security (encryption)
- the DNS management: focus on being trustful (a.k.a not being seen as spam)

## TL;DR *"I just want to copypaste the config and have a mail server now"*

Well, sadly there's no valid TL;DR here :(

Setting up a mail server requires time. This is a long post that has to be tackled with patience.

If you don't have enough time then [this](https://workspace.google.com/business/signup/welcome) is your best choice (and normally it's always the best choice)

## Requirements

You will need:

- a host with a public IP and a Debian-based distro installed, Ubuntu Focal used for this post
- a domain name pointing to this IP
- access to configure the DNS zones of that domain

## Understanding the basics
We all know the concept about sending an email and receiving it, so here we have two actions.
For both actions the "email" world has established protocols that the applications can follow.
For sending we have the [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) protocol thanks to the [ARPANET](https://en.wikipedia.org/wiki/ARPANET) in 1983 and for receiving we have [IMAP](https://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) and [POP3](https://en.wikipedia.org/wiki/Post_Office_Protocol).
For the sake of living in the present and keeping this documentation simple we can just focus on SMTP (send) and IMAP (receive).

The title of this post includes two buzzwords "Postfix" and "Dovecot", we can map them:

- Postfix -> SMTP
- Dovecot -> IMAP

So we have a Postfix to send email and a Dovecot to receive email (well, not exactly)

Let's work a bit more on the previous affirmation, and for that let's show a simple structure of clients and servers sending an email.

Imagine that Bob wants to send an email to Alice.
Bob has his own client and his own mail server, and Alice the same, something like this:

    - [Bob client]      -> speaks with -> [Bob Server]
    - [Alice client]    -> speaks with -> [Alice Server]

Imagine we have `[Bob server]` working under `@bob.com` and `[Alice Server]` under `@alice.com`.
How does an email travel from Bob to Alice?
First the client sends an email to its own SMTP server and then the SMTP server checks the `@destination.com` and sends it to the IP of that `@destination.com`, in this case `@alice.com` which identifies `[Alice Server]`.

So if Bob sends an email to `alice@alice.com` this will be the path to follow:

    - [Bob client] -> [Bob Server][SMTP] -> relay -> [Alice Server][SMTP] -> [Alice client]

Here appears the buzzword `relay` which basically is the same between client->server but between SMTP Servers.

Ok, nice, and where is IMAP? Do we need it? Maybe not, maybe yes. The truth is that we need it.
Once `[Bob server][SMTP]` has relayed Bob's email to `[Alice Server][SMTP]`, `[Alice Server][SMTP]` validates the email (spam, etc) and if it's ok then the email is sent to `[Alice Server][IMAP]`.
So the whole traveling would be something like this:

1. `[Bob client]`:
    - writes an email with `alice@alice.com` as recipient
    - sends this email to `[Bob server][SMTP]`
2. `[Bob server][SMTP]`:
    - authenticates `[Bob client]` (if no auth, no email)
    - relays the email to `[Alice Server][SMTP]` (it has to find the IP based on the `@alice.com`)
3. `[Alice Server][SMTP]`:
    - validates the email comming from `[Bob server][SMTP]`
    - sends the email to `[Alice Server][IMAP]`
4. `[Alice client]`:
    - requests new email to `[Alice Server][IMAP]`
5. `[Alice Server][IMAP]`:
    - authenticates `[Alice client]` (if no auth, no email)
    - provides the email contents to `[Alice client]`
6. `[Alice client]`:
    - enjoys Bob's [content](https://youtu.be/xvFZjo5PgG0){target=_blank}

So:

    [client] -> [SMTP] -> relay -> [SMTP] -> [IMAP] -> [client]

Now we know the travelling but why we add an IMAP there? Why not just querying from the client directly to the SMTP?
Ok, that's a good one. Maybe it's because somebody decided to implement it like this with this protocol, but the concept is:

- SMTP sends and receives, but it doesn't care about storing
- IMAP does, he worries about storing

So SMTP for the travelling between mail servers and IMAP to manage all the received emails.

POP3 is like IMAP but older and with less features.

Disclaimer: All the previous summary is very rough top level without going into details, it's a bit more complicated but more or less this is the main idea.

Ok, so now we know a bit the basics and to complete this chapter it's important to mention 3 concepts and keep them in mind:

- Auth: as we live in an Internet world we need to demonstrate that we are who we are and allow using the service only to ourselves.
- DNS: the same, to demonstrate that we are who we are, but instead to ourselves, to the world.
- Encrypting: there are lots of voyeurs out there, we have to keep our content private.

These concepts will be tackled more in deep in their sections, this was just a little spoiler to be prepared. Now let's move on to the practice part.

## Setting up Postfix (v3.4.13)

What's Postfix? This is an easy one, an SMTP server.

How to install it? `apt install postfix` and you can ignore all that wizard because we are going to rewrite the config.

What do we want Postfix for? We want to send an email and also to receive it, we need to `relay` and to be `relayed` so we need to configure a couple of things.

First of all, postfix has two main config files:

    /etc/postfix/main.cf
    /etc/postfix/master.cf

The `main.cf` is for the generic config and the `master.cf` is to define the services that Postfix will run.
And now here raises a question: Which services do we need? Isn't enough with SMTP? Well, yes and no, it's enough with SMTP as protocol but Postfix runs many services.

Before going into details, first, let's copy these config files and replace all `{REPLACE_*}` in `main.cf`, the `master.cf` can be copied as it is:

For example in my case:

    myhostname = mail.{REPLACE_YOURDOMAIN}
    # replace with
    myhostname = mail.oalfonso.com

=== "main.cf"

    ``` c++
    # ID
    myhostname = mail.{REPLACE_YOURDOMAIN}
    myorigin = /etc/mailname
    mydestination = $myhostname, {REPLACE_YOURDOMAIN}, localhost.localdomain, localhost

    # General
    syslog_name=postfix/generic
    smtpd_banner = $myhostname ESMTP $mail_name ({REPLACE_YOURDISTRO})
    append_dot_mydomain = no
    compatibility_level = 2

    # Network
    mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
    inet_interfaces = {REPLACE_YOURIP},127.0.0.1
    smtp_bind_address = {REPLACE_YOURIP}
    inet_protocols = all
    smtp_address_preference = ipv4

    # TLS
    smtpd_tls_cert_file=/etc/letsencrypt/live/mail.{REPLACE_YOURDOMAIN}/fullchain.pem
    smtpd_tls_key_file=/etc/letsencrypt/live/mail.{REPLACE_YOURDOMAIN}/privkey.pem
    smtpd_tls_security_level = encrypt
    smtpd_tls_protocols = >=TLSv1.2
    smtpd_tls_loglevel = 1
    smtpd_tls_received_header = yes
    smtpd_tls_auth_only = yes
    smtp_tls_note_starttls_offer = yes
    smtp_tls_security_level = encrypt

    # Auth
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable=yes

    # Mail config
    mailbox_size_limit = 0
    recipient_delimiter = +
    home_mailbox = Maildir/

    # Aliases
    alias_maps = hash:/etc/aliases
    alias_database = hash:/etc/aliases

    # Milter
    milter_protocol = 6
    milter_default_action = accept
    milter_macro_daemon_name=ORIGINATING
    smtpd_milters = inet:localhost:12301
    non_smtpd_milters = inet:localhost:12301

    ```

=== "master.cf"

    ``` c
    # ==========================================================================
    # service type  private unpriv  chroot  wakeup  maxproc command + args
    #               (yes)   (yes)   (no)    (never) (100)
    # ==========================================================================
    smtp      inet  n       -       y       -       -       smtpd -v
    smtps     inet  n       -       y       -       -       smtpd -v
    submission inet n       -       -       -       -       smtpd -v
        -o syslog_name=postfix/submission
        -o smtpd_tls_wrappermode=no
        -o smtpd_tls_security_level=encrypt
        -o smtpd_sasl_auth_enable=yes
        -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
        -o milter_macro_daemon_name=ORIGINATING
        -o smtpd_sasl_type=dovecot
        -o smtpd_sasl_path=private/auth

    pickup    unix  n       -       y       60      1       pickup
    cleanup   unix  n       -       y       -       0       cleanup
    qmgr      unix  n       -       n       300     1       qmgr
    tlsmgr    unix  -       -       y       1000?   1       tlsmgr
    rewrite   unix  -       -       y       -       -       trivial-rewrite
    bounce    unix  -       -       y       -       0       bounce
    defer     unix  -       -       y       -       0       bounce
    trace     unix  -       -       y       -       0       bounce
    verify    unix  -       -       y       -       1       verify
    flush     unix  n       -       y       1000?   0       flush
    proxymap  unix  -       -       n       -       -       proxymap
    proxywrite unix -       -       n       -       1       proxymap
    smtp      unix  -       -       y       -       -       smtp
    relay     unix  -       -       y       -       -       smtp
        -o syslog_name=postfix/$service_name
    showq     unix  n       -       y       -       -       showq
    error     unix  -       -       y       -       -       error
    retry     unix  -       -       y       -       -       error
    discard   unix  -       -       y       -       -       discard
    local     unix  -       n       n       -       -       local
    virtual   unix  -       n       n       -       -       virtual
    lmtp      unix  -       -       y       -       -       lmtp
    anvil     unix  -       -       y       -       1       anvil
    scache    unix  -       -       y       -       1       scache
    postlog   unix-dgram n  -       n       -       1       postlogd

    maildrop  unix  -       n       n       -       -       pipe
        flags=DRhu user=vmail argv=/usr/bin/maildrop -d ${recipient}
    uucp      unix  -       n       n       -       -       pipe
        flags=Fqhu user=uucp argv=uux -r -n -z -a$sender - $nexthop!rmail ($recipient)

    ifmail    unix  -       n       n       -       -       pipe
        flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r $nexthop ($recipient)
    bsmtp     unix  -       n       n       -       -       pipe
        flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t$nexthop -f$sender $recipient
    scalemail-backend unix	-	n	n	-	2	pipe
        flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store ${nexthop} ${user} ${extension}
    mailman   unix  -       n       n       -       -       pipe
        flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
        ${nexthop} ${user}
    ```

Ok now we have a bunch of config lines that we don't know and they don't even work because they are assuming things that we have not yet configured.

Let's try to understand it first.

### Config file `main.cf`

Brief description of each parameter:

- ID:
    - [myhostname](https://www.postfix.org/postconf.5.html#myhostname): This is the [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name){target=_blank} that must have an [MX DNS](https://en.wikipedia.org/wiki/MX_record){target=_blank} record pointing to this IP
    - [myorigin](https://www.postfix.org/postconf.5.html#myorigin): The contents of `/etc/mailname` should contain a valid hostname for your mail server. This is used by applications like cron, we can put the same as $myhostname in `/etc/mailname`.
    - [mydestination](https://www.postfix.org/postconf.5.html#mydestination): This parameter specifies the domains from which we will accept emails to be sent. So if you send a request from a `bob@mail.com` and `mail.com` is not in this list, `bob` will have to find another way to send his email.
- General:
    - [syslog_name](https://www.postfix.org/postconf.5.html#syslog_name): name of the logger in syslog to identify the logs. This can be overriden in each service in `master.cf`
    - [smtpd_banner](https://www.postfix.org/postconf.5.html#smtpd_banner): Message returned by the server to present himself, it's a convention and if is not respected some servers (like Gmail) can tag you as spam.
    - [append_dot_mydomain](https://www.postfix.org/postconf.5.html#append_dot_mydomain): prevents sending emails to things like "user@partialdomainname" because the `.com` won't be automatically added. We prefer to don't modify the domains.
    - [compatibility_level](https://www.postfix.org/postconf.5.html#compatibility_level): To not go into too many details, less than 2 can accept backwards compatibility but as we are installing this version from scratch we can set all the configuration parameters without backwards compatibility.
- Network
    - [mynetworks](https://www.postfix.org/postconf.5.html#mynetworks): The list of "trusted" remote SMTP clients that are allowed to relay mail through Postfix.
    - [inet_interfaces](https://www.postfix.org/postconf.5.html#inet_interfaces): The local network interface addresses that this mail system receives mail on
    - [smtp_bind_address](https://www.postfix.org/postconf.5.html#smtp_bind_address): IP used to send emails. Needed if we have multiple interfaces, and more important if they are public interfaces, because we will setup DNS records to give us more truthworthship that will declare our public IP as the source of the server and it has to match to the IP used by Postfix, if not other SMTP servers can decide to don't trust us.
    - [inet_protocols](https://www.postfix.org/postconf.5.html#inet_protocols): The Internet protocols Postfix will attempt to use when making or accepting connections, options: ipv4, ipv6 or all which are both.
    - [smtp_address_preference](https://www.postfix.org/postconf.5.html#smtp_address_preference): Try to use this protocol before the other, if ipv4 specified Postfix will use ipv4 always as the first option.
- TLS
    - [smtpd_tls_cert_file](https://www.postfix.org/postconf.5.html#smtpd_tls_cert_file): TLS cert, we will request one from Letsencrypt with Certbot
    - [smtpd_tls_key_file](https://www.postfix.org/postconf.5.html#smtpd_tls_key_file): TLS key, we will request one from Letsencrypt with Certbot
    - [smtpd_tls_security_level](https://www.postfix.org/postconf.5.html#smtpd_tls_security_level): Specify `encrypt` for mandatory TLS encryption for the SMTP server.
    - [smtpd_tls_protocols](https://www.postfix.org/postconf.5.html#smtpd_tls_protocols): Declare the accepted protocols for TLS, we only want v1.2 or greater.
    - [smtpd_tls_loglevel](https://www.postfix.org/postconf.5.html#smtpd_tls_loglevel): Use 2 or higher to debug problems, if not, it can be with 0 as default which is disabled or 1 which is the basic.
    - [smtpd_tls_received_header](https://www.postfix.org/postconf.5.html#smtpd_tls_received_header): Add TLS details in the Received field, so when inspecting the original message received from others we can check the TLS details.
    - [smtpd_tls_auth_only](https://www.postfix.org/postconf.5.html#smtpd_tls_auth_only):  When TLS encryption is optional in the Postfix SMTP server, do not announce or accept SASL authentication over unencrypted connections.
    - [smtp_tls_note_starttls_offer](https://www.postfix.org/postconf.5.html#smtp_tls_note_starttls_offer):  Log the hostname of a remote SMTP server that offers STARTTLS, when TLS is not already enabled for that server.
    - [smtp_tls_security_level](https://www.postfix.org/postconf.5.html#smtp_tls_security_level): Use `encrypt` to force the SMTP client to use TLS.
- Auth
    - [smtpd_sasl_type](https://www.postfix.org/postconf.5.html#smtpd_sasl_type): As [SASL](https://en.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer){target=_blank} type we will specify `dovecot` to use the auth system of our IMAP server.
    - [smtpd_sasl_path](https://www.postfix.org/postconf.5.html#smtpd_sasl_path): Relative path to $queue_directory used to comunicate Postfix and Dovecot. This can also be configured via TCP.
    - [smtpd_sasl_auth_enable](https://www.postfix.org/postconf.5.html#smtpd_sasl_auth_enable): To enable SASL.
- Mail config
    - [mailbox_size_limit](https://www.postfix.org/postconf.5.html#mailbox_size_limit): Use 0 for unlimited mailbox size, the limit will be the host disk.
    - [recipient_delimiter](https://www.postfix.org/postconf.5.html#recipient_delimiter): Postfix allows you to specify a character to separate the user from an additional string. For example with a `+` as `recipient_delimiter` we can have the mail `user@mail.com` and also `user+extrastring@mail.com` and we will get the mails delivered to `user`. This is helpful for example when we want to check if a third party who has our address is providing our address to others, for example we provide to `randomco.com` our address `user+rco@mail.com` and later we receive an email from `spamco.com` to `user+rco@mail.com`, that is pretty clear, `randomco.com` has not being playing fair.
    - [home_mailbox](https://www.postfix.org/postconf.5.html#home_mailbox): The default dir in the home of each user which will contain all the mails.
- Aliases
- Milter
    - [milter_macro_daemon_name](https://www.postfix.org/postconf.5.html#milter_macro_daemon_name): The name of the daemon of the [milter](https://en.wikipedia.org/wiki/Milter) that we are going to configure together with [OpenDKIM](http://www.opendkim.org/) to be more trustful, ignore for now.

### Config file `master.cf`

Contains services like:

    pickup, cleanup, qmgr, tlsmgr, rewrite, bounce, defer, trace, verify, flush, proxymap, proxywrite, smtp, relay, showq, error, retry, discard, local, virtual, lmtp, anvil, scache, postlog, maildrop, uucp, ifmail, bsmtp, scalemail, mailman

What are they doing? I'm not sure, they come preconfigured in the `master.cf` as you can see but we can focus on just 3 services:

    smtp, smtps, submission

But first, let's see the header of this config file:

    # ==========================================================================
    # service type  private unpriv  chroot  wakeup  maxproc command + args
    #               (yes)   (yes)   (no)    (never) (100)
    # ==========================================================================

And the first service, `smtp` goes like this:

    smtp      inet  n       -       y       -       -       smtpd -v

Which means bla bla bla

The other is `smtps`:

    x y z

which means other thing

And last, `submission`:

    x w h

Is doing x movidas and look at the `-o`, those override the parameters present in `main.cf`

## Dovecot time

## Certificates

## DNS

## Security

- SPF
- DKIM
- DMARC

