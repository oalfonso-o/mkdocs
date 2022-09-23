# Ansible

This post will only cover how to do a basic setup of Ansible, how to define your configuration of a host with the basic concepts which are:

- Why ansible
- How it works
- Installing ansible
- Understanding the playbooks/roles/tasks
- Defining hosts
- Variables
- Vault: encrypt your secrets

With these concepts we are ready to define our configuration of our servers with Ansible.

Other requirements:

- Having an instance to which we have ssh access. It can be an EC2 in AWS, docker instance in local or even a vagrant in local too.

## Why Ansible

Normally we do ssh to one of our servers and start configuring things. This is perfectly fine but if we have configured a deployment of a production application which is important for our business maybe we want to be able to replicate the deployment without having to remember all the steps. Imagine that you spend 2 days configuring an Nginx with uwsgi-emperor and all the required vassals to serve some Python applications. You have installed apt packages, some nginx sites, the config for the emperor, the ini files of the vassals, the code for the Python applications, and so on. Imagine this is all on GCP but now you want to move it to AWS. You will need to spend another 2 days, or maybe at least 1 (because now you are more familiar with the steps) to reconfigure everything manually.

If you write all these steps in Ansible you don't need to pay the price of 1 or 2 days configuring things again. You can just run Ansible against the new host and everything will be configured as it was before in a couple of minutes.

Things to know:

- Ansible defines everything in `yaml` files.
- Ansible is conceptually idempotent, the idea is that if you run it multiple times the output of the configuration will be always the same. This sometimes is not 100% true if we don't define the tasks properly, but we have to do our best to have it 100% idempotent.

## How it works

If you are familiar with Puppet, you will know that Puppet has a master node which contains the configuration and then there are other hosts where you install a client and this client does periodic requests to the master node to be able to know if there's something to configure. So all hosts need access to the master node.

In Ansible this is different, there's no master. We need access by ssh to the host where we want to run the configuration and that host needs Python because ansible runs commands with Python.

## Installing Ansible

Now that we understand the basics, let's get dirty:

```
pip install ansible
```

That's it, we have Ansible. You can create a virtualenv or whatever that makes you more comfortable but the thing is that we can get ansible via `pip`.

## Understanding the Playbooks, Roles and Tasks

The most basic element of Ansible is a Task, which can be seen as the smallest config definition, it can be for example declaring that a directory has to exist, or a system user has to exist. Then there are two more elements, Roles and Playbooks. Roles are a bunch of tasks that will ensure an specific configuration, like for example installing and configuring an HTTP server. And a Playbook is normally what we run, which has the relation between hosts and roles/tasks that will be run in those hosts, for example: myserver.com with role: "install HTTP".

### Tasks

A task in ansible is defined as an "action". The most common tasks are builtins that already exist in Ansible like:

``` yaml linenums="1"
- name: apt install nginx
  apt:
    name: nginx
```
where [`apt`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html) is the task and we can check the documentation of that task to see the parameters accepted. The name can be a single element or a list of apt packages that Ansible will try to install. As we can see, the benefits of this is that we don't have to worry about the syntax of the system, we only specify that we want that package installed. We can also specify the version of the packages.

We can see another example with creating a [`user`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html):

``` yaml linenums="1"
- name: Add the user 'johnd' with a specific uid and a primary group of 'admin', specific uid and gen ssh key
  ansible.builtin.user:
    name: johnd
    shell: /bin/bash
    comment: John Doe
    uid: 1040
    group: admin
    generate_ssh_key: yes
    ssh_key_bits: 2048
    ssh_key_file: .ssh/id_rsa
```

As we can see, now with a single task we are defining many things, not just the name of the user, and everything with just a single task. The tricky part here is checking the documentation to know how the `user` builtin works.

We can specify the opposite too, we can configure that we don't want a user to exist:

``` yaml linenums="1"
- name: Remove the user 'johnd'
  ansible.builtin.user:
    name: johnd
    state: absent
    remove: yes
```

### Roles

Ok we know what is a task, but what is a role? A task we know that are lines of code, a role contains tasks so it is composed of more files, this is the structure of directories of a role:

```
roles/
    install_http_server/  # this hierarchy represents a "role"
        tasks/            #
            main.yaml     #  <-- tasks file can include smaller files if warranted
        handlers/         #
            main.yaml     #  <-- handlers file
        templates/        #  <-- files for use with the template resource
            conf.j2       #  <------- templates end in .j2 because are Jinja2
        files/            #
            bar.txt       #  <-- files for use with the copy resource
            foo.sh        #  <-- script files for use with the script resource
        vars/             #
            main.yaml     #  <-- variables associated with this role
        defaults/         #
            main.yaml     #  <-- default lower priority variables for this role
        meta/             #
            main.yaml     #  <-- role dependencies
        library/          # roles can also include custom modules
        module_utils/     # roles can also include custom module_utils
        lookup_plugins/   # or other types of plugins, like lookup in this case
```

When running a role, the entrypoint will be `tasks/main.yaml` and that file will contain the tasks. There's no need to explain all the possibilities of a role, we can just understand that we can contain
all the tasks for an specific configuration inside of a role.

### Playbooks

Playbooks are what we run with the command `ansible-playbook` and they run tasks or roles to specific hosts. A sample:

``` yaml linenums="1" title="install_all.yaml"
---
- hosts: myhosts
  roles:
    - install_http_server
    - create_users
```

If we run this playbook it will try to install the roles `install_http_server` and `create_users` to the group of hosts `myhosts`. But what are `myhosts`? Let's move to the next chapter of [Defining hosts](#defining-hosts).


## Defining hosts

The master piece here is the `inventory`. An inventory is a file that contains a list of hosts that our ssh client can identify. Also, these hosts can be defined in groups, so we can run tasks/roles to specific hosts or specific groups.

To make our work easier in Ansible when specifying hosts a good practice is using the `config` ssh file and put there all the specifics of the hosts and then here in our inventories specify only the `name` of the host and our ssh client will resolve all the needed config using the `config` file.

For example, if we have a host with IP `1.2.3.4` and we do ssh with the root user, we can write this `config` file:

``` linenums="1" title="~/.ssh/config"
Host        httphost
Hostname    1.2.3.4
User        root
```

Now we can do ssh with only `ssh httphost` instead of `ssh root@1.2.3.4`. And the same in the `inventory`, we can use the id `httphost` in our ansible inventory.

!!! info ""

    Here we are assuming that the pub key is in the `authorized_keys` of the remote host.

So we can define an inventory, which is just a file in our ansible project, normally at root level named `hosts`:

``` linenums="1" title="hosts"
httphost

[myhosts]
httphost
```

Here now we are specifying that we have a host that is called `httphost`, so ansible will be able to find it, and also, we are assigning the group `myhosts` to our host `httphost`. So we can run tasks and roles to the host `httphost` using both names. Ansible doesn't allow you to use the same name for hosts and groups, if one is defined then an exception will occur in case of overlap.

So now to run our playbook seen before in [Playbooks](#playbooks) we can just do:

``` bash
$ ansible-playbook install_all.yaml -i hosts
```

You can also add `-v`, `-vv` (try with more `v` for more verbose levels), `--check`, `--list-hosts` to understand what's happening with the run. Also the `--limit-hosts` to specify a comma-separated (without spaces) list of hosts/groups and ignore the others.

## Variables

We can specify values of the tasks with variables, which is very useful for example in roles. We can reuse a role for many different hosts. A role that installs a user with some specifics can allow you to define the name of the user with a variable, and then change this variable at host level. So the same role installed in `host1` can have `name1` and then installed in `host2` can have `name2`.

For this, it's important to know in which places we can put variables and which is the precedence.

First let's see the directory structure of an ansible project with the elements that we've seen:

```
group_vars/
    myhosts.yaml
host_vars/
    httphost.yaml
    host1.yaml
    host2.yaml
roles/
    install_http_server/
        tasks/
            main.yaml
        handlers/
            main.yaml
        templates/
            site.j2
        defaults/
            main.yaml
    create_users/
        tasks/
            main.yaml
        defaults/
            main.yaml
install_all.yaml
hosts
requirements.txt
```

We see here few more elements:

- requirements.txt: this can be ignored, is just to specify that Ansible is installed as a pip package
- hosts: this is the inventory
- install_all.yaml: this is our playbook
- group_vars: each file here has to be named with the name of a group in our inventory, here we can define variables that will act at group level.
- host_vars: each file here has to be named with the name of a host in our inventory, here we can define variables that will act at host level.
- roles/create_users/defaults/main.yaml: these variables are acting by default at the role level

The definition of variables is pure yaml, an example:
``` yaml linenums="1"
user_name: "johnd"
dict:
    element1: value1
    element2: value2
list:
    - item1
    - item2_dict:
        keyX: valueX
```

And in a task we can replace the hardcoded name with the variable doing:
``` yaml linenums="1"
- name: Add the user
  ansible.builtin.user:
    name: {{ name }}
```

Now, we can take a look at the precedence of the variables, see when our variable is going to be overridden so we can define our project structure. The following list is from less to more precedence:

    1    command line values (for example, -u my_user, these are not variables)
    2    role defaults (defined in role/defaults/main.yml) 1
    3    inventory file or script group vars 2
    4    inventory group_vars/all 3
    5    playbook group_vars/all 3
    6    inventory group_vars/* 3
    7    playbook group_vars/* 3
    8    inventory file or script host vars 2
    9    inventory host_vars/* 3
    10   playbook host_vars/* 3
    11   host facts / cached set_facts 4
    12   play vars
    13   play vars_prompt
    14   play vars_files
    15   role vars (defined in role/vars/main.yml)
    16   block vars (only for tasks in block)
    17   task vars (only for the task)
    18   include_vars
    19   set_facts / registered vars
    20   role (and include_role) params
    21   include params
    22   extra vars (for example, -e "user=my_user")(always win precedence)


## Vault: encrypt your secrets

Now we have all the basics needed to define our config in Ansible, but there's another thing that we will have to face many times when configuring production environments which are the secrets. It's a very unsafe and bad practice to persist plain secrets in a git repository even if it's private, those secrets will be spread across the company, end in many laptops and many places and this situation increases the risk of eventually sharing those secrets with bad actors. So better encrypting our secrets.

Ansible provides us with a very useful tool called [vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html).

To make it simple, it uses a single secret to encrypt all our secrets, so we can put them in git, and then when running the playbook we provide the same secret to decrypt the secrets.

So we need first a file with a random value, which can be generated for example like this:

```
openssl rand -hex 12 > .vault_id
```

Now you have to ignore this file in git and manage this secret properly with a secrets manager or your desired way.

### Encrypt a variable

The tool is `ansible-vault` and you can do:

```
$ ansible-vault encrypt_string --vault-pass-file .vault_id
```

This will prompt you to write your secret, then type ++ctrl++ + D twice to encrypt the secret:

```
Reading plaintext input from stdin. (ctrl-d to end input, twice if your content does not already have a newline)
aaa
!vault |
          $ANSIBLE_VAULT;1.1;AES256
          61333332353932316561633430383230666566623261333239626634386265393565356665336233
          3032636566336233646138383237313563623566653866370a626663633661636364363834373037
          65393730386139313063313632386332616431626266343833653634353838646236646134626236
          3730313165373338610a376163626136373765393535306433336337353565386262633334393361
          6466
Encryption successful
```

You can now copy this var and place it anywhere in the yaml files:
``` yaml linenums="1"
user_name: "johnd"
user_pwd: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          61333332353932316561633430383230666566623261333239626634386265393565356665336233
          3032636566336233646138383237313563623566653866370a626663633661636364363834373037
          65393730386139313063313632386332616431626266343833653634353838646236646134626236
          3730313165373338610a376163626136373765393535306433336337353565386262633334393361
          6466
```
!!! info ""

    Copy it as it is, from the `!vault` until the end, without removing indents.


### Decrypt a variable

There are multiple ways which can be googled, but one simple and fast way is to place the secret in a new file but without indents, just the encrypted text:

``` linenums="1" title="myencryptedvar"
$ANSIBLE_VAULT;1.1;AES256
61333332353932316561633430383230666566623261333239626634386265393565356665336233
3032636566336233646138383237313563623566653866370a626663633661636364363834373037
65393730386139313063313632386332616431626266343833653634353838646236646134626236
3730313165373338610a376163626136373765393535306433336337353565386262633334393361
6466
```

And then run:

```
$ ansible-vault decrypt --vault-pass-file .vault_id --output mydecryptedvar myencryptedvar
Decryption successful
```

You can now read the original content of that var in the new file:

```
$ cat mydecryptedvar
aaa
```

And that's all for understanding the basics. Enjoy your configuration as code :)