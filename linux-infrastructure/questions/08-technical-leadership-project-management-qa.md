# Q&A: Technical Leadership and Project Management for SRE

Pairs with: [08-technical-leadership-project-management.md](../08-technical-leadership-project-management.md)

> 10 interview-grade questions on leadership, communication, and project management for senior SREs.

---

## Q1. What does "technical leadership" mean for a senior SRE?
**Answer:**  
- Setting **direction** for technical decisions, often via design docs and architecture reviews.  
- Making **trade-off decisions** when the team disagrees, with data and clear reasoning.  
- Multiplying impact by enabling others (mentoring, code review, runbooks, design feedback).  
- Representing the team in cross-team discussions, incident reviews, and leadership forums.  
- Owning the **outcome**, not just the work.  
- Knowing when to write code yourself versus delegate.

## Q2. How do you lead a technical project from concept to launch?
**Answer:**  
1. **Define the problem** in writing: goals, non-goals, success metrics.  
2. **Explore options** and write a short design doc with trade-offs.  
3. **Plan** milestones, owners, and dependencies.  
4. **Execute** with weekly tracking and clear updates.  
5. **Communicate** progress, risks, and blockers proactively to stakeholders.  
6. **Launch** with validation against the success metrics.  
7. **Retrospect**: capture what worked, what did not, and follow-ups.

## Q3. How do you keep a cross-team project on track when other teams have different priorities?
**Answer:**  
- Make dependencies **explicit and visible** in the plan.  
- Get cross-team commitments **in writing** with named owners and dates.  
- Run a **regular sync** with all stakeholders.  
- Track each dependency with status (`on track`, `at risk`, `blocked`).  
- Escalate early when commitments slip; do not wait for the deadline.  
- Offer help: sometimes the unblocking is faster if your team contributes work.

## Q4. How do you communicate progress to leadership without overwhelming them?
**Answer:**  
- Provide a **short weekly summary**: progress, risks, decisions needed, asks.  
- Use a consistent format so leaders can scan quickly.  
- Lead with the **bottom line**: are we on track or not, and why.  
- Show metrics and milestone status, not raw activity.  
- Save deep technical details for backup or appendix.  
- Surface **decisions needed** clearly; do not bury them in narrative.

## Q5. How do you escalate effectively without sounding alarmist?
**Answer:**  
- State the **impact** in business terms.  
- List the **options** with pros and cons.  
- Give your **recommendation**.  
- Specify the **decision needed** and **by when**.  
- Avoid finger-pointing; focus on the path forward.  
- Escalate **early**: a known risk shared early is far easier to handle than a surprise.

## Q6. How do you mentor or coach a more junior SRE?
**Answer:**  
- Understand their **goals** and current skill gaps.  
- Pair on real work (incidents, design reviews, code reviews) and explain reasoning out loud.  
- Give them stretch assignments with a safety net.  
- Provide **timely, specific feedback** — what was good, what could improve, and why.  
- Coach on **systems thinking**, not just commands.  
- Celebrate growth and let them present their work in team forums.

## Q7. How do you handle a disagreement with a peer engineer on a technical decision?
**Answer:**  
- Listen first; restate their position to confirm understanding.  
- Bring **data** to the discussion rather than opinions.  
- Identify the **real trade-off** and the **constraints** at play.  
- Look for ways to test the decision (prototype, benchmark, data review).  
- If no agreement is reached, escalate to a shared technical owner with both options written down.  
- Once a decision is made, **support it** even if it was not your preferred choice.

## Q8. How do you decide what work to do yourself versus delegate?
**Answer:**  
- Delegate when:
  - The work is a growth opportunity for someone else.
  - The work is critical-path but not the highest leverage for you.
  - There is enough scope for clear ownership.
- Do it yourself when:
  - The work requires context only you have, briefly.
  - It is a high-risk decision where you must be accountable.
  - It is a fast-fix that would take longer to explain than do.
- Always provide context when delegating; do not just hand over a task.

## Q9. How do you run a productive design review meeting?
**Answer:**  
- Share the **design doc 24-48 hours** before the meeting.  
- Use the meeting for **questions, trade-offs, and decisions**, not for reading the doc.  
- Have a **facilitator** to keep time and topics on track.  
- Capture **decisions and follow-ups** in writing during the meeting.  
- Make sure dissenting opinions are heard and addressed.  
- End with clear **next steps** and **owners**.

## Q10. How do you raise the technical bar of a team over time?
**Answer:**  
- Lead by example: high-quality code, runbooks, postmortems, design docs.  
- Run regular **brown-bag sessions** on new tools, incidents, or industry trends.  
- Review code and designs with **teaching feedback**, not just gatekeeping.  
- Encourage engineers to **share their work** in team forums.  
- Build a **library of references**: design docs, postmortems, runbooks, internal articles.  
- Recognize and reward people who help others, not just heroes who fix incidents.
