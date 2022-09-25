# KISS

[KISS](https://en.wikipedia.org/wiki/KISS_principle) stands for `Keep It Simple, Stupid`, you can read the Wikipedia page for more details, it's very interesting, but the key point is: don't complicate your life. This is obvious, but when we don't have this principle very present we reach complex situations that have a negative impact in our company. Let's see a couple of examples.

## When the most important is not the most important

Imagine being part of a big company. Imagine having to solve a problem. Imagine now that this problem is big enough to have a team, a client, a project, a budget. You have X time to do Y features.

Now imagine reaching the deadline and not having Y features. The client is not happy, your boss is not happy and nobody can explain what happened. Does this sound familiar? No? Good for you, but unfortunately I've seen this case many times and is not pleasant.

I've seen many times people planning to do features that are not critical for the MVP, but they plan those features to be done before the critical ones.

I've seen plenty of times projects that don't reach the deadline but they have many features that can't be used in production yet.

I've also seen a project with non-critical features developed 3 years before the go-live stage, not tested in production, so once in production these features were obsolete and they had to be removed and start them again from scratch, no refactor was possible there. Months of development wasted.

The problem here is that sometimes we put at the same level the critical feature and the "nice to have" feature. **The client is always going to request as many things as possible for the less price and less time available.** But we should know that we are not going to provide everything to our client (and the client can be external or internal, doesn't matter, the client is the third party that is requesting some features).

Let's put an example. Imagine a client which requests us a data processing pipeline that should process daily music usages from Spotify (we get the data from Spotify in behalf of our client using their legal agreement) and generate daily reports from these usages and present them in a web interface, the data that the client wants to know is their revenue in Spotify by day/month. Here we can list the critical features and the "nice to have" features:

- Critical:
    - Download Spotify data daily
    - Process Spotify data daily
    - Having a web platform
        - Granting access to the client
        - Show the daily revenue data
        - Show the monthly revenue data
- Nice to have:
    - Good UI/UX
    - Notifications
    - Platform scalability for N users
    - BI with multiple charts

Now let's do some raw estimations:

- Critical: **(4 weeks)**
    - **1 week**  - Download Spotify data daily
    - **1 week**  - Process Spotify data daily
    - **2 weeks** - Having a web platform
        - **1 week**   - Granting access to the client
        - **1/2 week** - Show the daily revenue data
        - **1/2 week** - Show the monthly revenue data
- Nice to have: **(7 weeks)**
    - **1 week**  - Good UI/UX
    - **2 weeks** - Notifications
    - **2 weeks** - Platform scalability for N users
    - **2 weeks** - BI with multiple charts

Ok, so the features that MUST be present are aprox 4 weeks and the features that add extra value but are not mandatory are aprox 7 extra weeks.

Now imagine not having any of the critical features but having all your developers of this team working on having good UI/UX, with the download and process features at 50% both, the web platform also at 50% because it's only in development status, not in production, and having spent already 8 weeks of development.

Let's extract some conclusions from this situation with budget numbers.

If this team has 3 people:

- project manager
- backend developer
- frontend developer

Let's imagine each of them costs 10$ (random number) per week.
The project is planned to be done in 2 phases, the first one with the critical features and then another with extra features.

In the first phase, we have planned to invoice 200$ to our client, because it will be done in 4 weeks, as we have planned. so the costs are aprox:

- 10$ * 3 people * 4 weeks = 120$ of cost
- revenue 200$ - 120$ = <green>**80$ of profit**</green>

But this is what was planned, now let's do the math with the situation that we've seen:

- 10 * 3 people * 8 weeks = 240$ of cost

And now, as we have the critical features at 50% of development, we can't invoice our client because we can't deliver our first phase.

Imagine that we finally close the phase 1 after 2 more weeks, because somebody realizes that we have been planning wrong, so we drive our development towards closing the first phase. So this will be the math:

- 10$ * 3 people * 10 weeks = 300$ of cost
- revenue 200$ - 300$ = <red>**-100$ of profit**</red>

Boom! We are losing money! This is not a sustainable way of doing business.

This example looks pretty obvious but I've seen this scenario many times.

### Which are the causes of this scenario?

This is the best question to do when we identify this, and it can be summarized to these 3 items or a combination of them:

- team not aligned with the goals of the company
- team not responsible/motivated for their job
- team not senior enough

At the end, this is a team problem. So the maximum guilty of this situation is the one leading/managing this team.

Who was the manager of this team? The project manager? The backend engineer? The frontend? Sometimes the project doesn't start with these roles clearly defined and it's pretty easy to arrive to these scenarios. People closing tickets but not understanding what the company tries to achieve with this project.

Having a manager who is totally responsible for achieving these company goals is key to avoid this situation. This manager can be the backend, the project manager or even a manager who is not solving any technical task, but is aware of the whole process and will be monitoring the whole process. Without this role, the risk is too high. Is like when you are with your friends going to a restaurant and after a couple of minutes somebody says: "Where are we going" "I don't know, I was following Bob" and Bob says: "Me? I was following Tom" and Tom went home 1 hour ago, so nobody knows where we are going but we keep walking randomly because it was what we were supposed to do.

### Learnings from this scenario

- Having a manager is critical, and somebody has to be responsible for assigning this manager.
- Focus first on the critical features, close one delivery, then move to the next one.

## When there are too many management tools

To plan successfully a project there are many tools:

- Google Spreadsheets
- Google Docs
- Jira
- Trello
- Kanbanize
- Asana
- Basecamp
- Physical whiteboards

And hundreds more.

It doesn't matter what you pick.

I've seen projects where multiple of these tools were used, by different people, in different ways, with duplicity and discrepancies.

For example, having a calendar in basecamp with delivery dates and then an spreadsheet with a timeline reflecting these delivery dates. Two different people are managing these two tools, so they try to keep them sync, but eventually we lose this sync. Until here is something that can be managed. But then appears a third person trying to reflect all of these in a digital board tool, which doesn't reflect the delivery dates and adds many more features. There's also a ticket in Jira for each task, but each ticket has to be linked to the tasks defined in each tool. Imagine having 30 Jira tasks to complete "Phase 1" and having to reflect them in the 3 tools:

- in the spreadsheet timeline we have 10 milestones, which link to 10 tickets in Jira
- in the Basecamp calendar we have 7 deliveries, which link to 7 tickets in Jira
- in the digital board tool we have the 30 tasks linked to 30 Jira tickets but without delivery dates, and also 30 more tasks that belong to Phase 2, but they are related so it's hard to isolate Phase 1 and Phase 2.

Pros of this:

- you have all the information

Cons of this:

- to check the deliveries you have to check 2 different tools, because two different people are managing 2 different types of deliveries, and eventually they are not going to be in sync
- to check all the tasks you have to check 4 different tools (spreadsheet, basecamp, the board and jira) and hope for having everything in sync
- eventually these 3 people will do changes in their own systems without reflecting the changes in the other systems
- this is very time consuming and frustrating when we can't gather the desired data

### How to solve this with the KISS principle?

- Have only 1 person responsible for this, this person can be anybody, the project manager, a developer or a manager.
- This person can use any combination of tools of her desire but has to be able to express everything in plain, without complexity. And for everything we understand:
    - phases of the project
    - milestones of each phase
    - all phases and milestones with clear deadlines
    - each milestone that has to be tackled in the near future needs to be clear, without uncertainty:
        - what has to be done -> clear [DoD](https://www.productplan.com/learn/agile-definition-of-done/)
        - who can tackle this
        - when this will be finished

If this person can achieve these two things and report the progress properly, there are no restrictions on the tooling, she can use as many tools as she wants.

## Conclusions

To avoid these kind of problems:

1. Accountability: having always a good manager, a single responsible.
2. Prioritize: this manager has to always drive the development towards the most important features in the first place.
3. Observability: this manager has to be able to report clearly the status of the project.

The KISS principle is not complex at all, is very plain, IMHO this can be translated to: have the best people doing the job. The best people always are aware of everything and they don't allow this kind of things to happen.
