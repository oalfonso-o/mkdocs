# Mail Server with Postfix and Dovecot

This post explains how to setup a [Postfix](https://www.postfix.org/) [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) server and a [Devocot](https://www.dovecot.org/) [IMAP](https://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) server.

## TLDR; I just want to copypaste and have a mail server now

Well, sadly there's no valid TLDR here :(

Setting up a mail server requires time. This is a long post that has to be tackled with patience.

If you don't have enough time for this then [this](https://workspace.google.com/business/signup/welcome) is your best choice (and normally it's always the best choice)

## Understanding the basics
So, we all know the concept about sending an email and receiving it, so here we have two actions.
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
How does an email travel crom Bob to Alice?
First the clients send an email to their own SMTP server and then the SMTP server checks the `@destination.com` and sends it to the IP of that `@destination.com`.

So if Bob sends an email to `alice@alice.com` this will be the path to follow:

    - [Bob client] -> [Bob Server][SMTP] -> relay -> [Alice Server][SMTP] -> [Alice client]

Here appears the buzzword `relay` which basically is the same between client->server but between SMTP Servers.

Ok, nice, and where is IMAP? Do we need it? Maybe not, maybe yes. The truth is that we need it.
Once `[Bob server][SMTP]` has relayed Bob's email to `[Alice Server][SMTP]`, `[Alice Server][SMTP]` validates the email (spam, etc) and if it's ok then the email is sent to `[Alice Server][IMAP]`.
So the whole traveling would be something like this:

1. `[Bob client]`:
    - writes an email to `alice@alice.com`
    - sends this email to `[Bob server][SMTP]`
2. `[Bob server][SMTP]`:
    - authenticates `[Bob client]` (if no auth, no email)
    - relays the email to `[Alice Server][SMTP]` (it has to find the IP based on the `@alice.com`)
3. `[Alice Server][SMTP]`:
    - validates the email comming from `[Bob server][SMTP]`
    - sends the email to `[Alice Server][IMAP]` (if `[Alice Server][SMTP]` says that everything is ok with that email)
4. `[Alice client]`:
    - requests new email to `[Alice Server][IMAP]`
5. `[Alice Server][IMAP]`:
    - authenticates `[Alice client]` (if no auth, no email)
    - provides the email contents to `[Alice client]`
6. `[Alice client]`:
    - enjoys Bob's [content](https://youtu.be/xvFZjo5PgG0)

So:

    [client] -> [SMTP] -> relay -> [SMTP] -> [IMAP] -> [client]

Now we know the travelling but why we add an IMAP there? Why not just querying from the client directly to the SMTP?
Ok, that's a good one. Maybe it's because somebody decided to implement it like this with this protocol, but the concept is:

- SMTP sends and receives, but it doesn't care about storing
- IMAP does, he worries about storing

So SMTP for the travelling between mail servers and IMAP to manage all the received emails.

POP3 is like IMAP but older and with less features.

We will need more concepts but there's enough text, the concepts that we will need are:

- Auth: as we live in an Internet world we need to demonstrate that we are who we are and allow using the service only to ourselves.
- DNS: the same, to demonstrate that we are who we are, but instead to ourselves, to the world.
- Encrypting: there are lots of voyeurs out there, we have to keep our content private.

And they will be tackled more in deep in their sections, so let's move on to the practice part.

## Setting up Postfix

What's Postfix? This is an easy one, SMTP server.
How to install it? `apt install postfix`
That's all? Uhhmm... more or less.
But we want to send an email and also to receive it, we need to `relay` and to be `relayed` so we need to configure a couple of things.

First of all, postfix has two main config files:

    /etc/postfix/main.cf
    /etc/postfix/master.cf

The `main.cf` is for the generic config and the `master.cf` is to define the services that Postfix will run.
And now here raises a question: Which services do we need? Isn't enough with SMTP? Well, yes and no, it's enough with SMTP as protocol but we need at least two SMTP services:

    the service to send emails to outside:            `submission`
    the service to receive emails from the outside:   I don't know the name

hehehe

## Devocot time

## Certificates

## DNS

## Security

- SPF
- DKIM
- DMARC

