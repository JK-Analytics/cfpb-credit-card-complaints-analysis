# CFPB Credit Card Complaints: Complaint Drivers and Relief Rate Analysis

**The question:** Which credit card complaint issues come up most often, and when customers complain about them, do they get real help or just an explanation?

**Tools:** SQL Server (SSMS), Excel

---

## Why I did this

In customer service, every customer's issue matters. But a team still has to decide where to look first, and that usually comes down to two things: which problems keep coming back, and which ones tend to leave customers without help. I wanted to see how far SQL could take me in answering that with real data.

## The data

- **Source:** the public Consumer Complaint Database run by the US Consumer Financial Protection Bureau (CFPB), filtered to the credit card product.
- **Size:** 97,861 complaints received between 17 August 2023 and 31 December 2024, covering 516 companies.
- **Worth knowing:** this is public regulator data, not any one company's internal tickets, and it covers US consumers. This project shows a method. It does not describe any Nigerian company.

## What I did

1. **Loaded the export into SQL Server** as `complaints_raw` and left it untouched. The row count matched the number shown on the CFPB page.
2. **Checked that every Complaint_ID is unique.** No duplicates.
3. **Tested my first idea and dropped it.** I started by asking whether busy periods slow responses down. But 99.83% of responses were on time (97,694 of 97,861), so speed isn't the problem here.
4. **Defined "relief" before measuring it.** Relief means the complaint was closed with monetary or non-monetary relief. I left out the 29 "Untimely response" rows, since they have no outcome.
5. **Split credit bureaus from card issuers.** Equifax, Experian and TransUnion account for 27,110 complaints (27.7%) and deal with different problems, like errors on a credit report. I did the split with a SQL view, so the raw data stayed as it was.
6. **Compared relief rate by issue, inside each group.**
7. **Set a cutoff for "high volume":** an issue counts as big if it makes up at least 5% of card issuer complaints. I then looked for big issues with below-average relief. Any cutoff between about 4.9% and 7.5% gives the same four issues.

## What I found

- Overall, **38.8%** of complaints ended in relief. That number hides a split: **bureaus 55.9%**, **card issuers 32.3%**. Bureaus look higher because correcting a credit report counts as relief, so I compare issues within a group and not across groups.
- Across all complaints, 61.2% ended with an explanation, 25.4% with non-monetary relief and 13.4% with monetary relief.

**Card issuers: big issues with below-average relief (average is 32.3%)**

| Issue | Complaints | Share of card issuer complaints | Relief rate |
|---|---|---|---|
| Getting a credit card | 10,724 | 15.2% | 31.1% |
| Other features, terms, or problems | 9,010 | 12.7% | 29.7% |
| Closing your account | 5,372 | 7.6% | 21.2% |
| Problem when making payments | 5,349 | 7.6% | 31.1% |

Two other big issues sit above average: "Problem with a purchase shown on your statement" (27.0% of complaints, 39.6% relief) and "Fees or interest" (11.2%, 41.3%). Two issues just under my cutoff are also worth watching: "Trouble using your card" (4.2% of complaints, 17.9% relief) and "Incorrect information on your report" (4.9%, 24.4%).

## Where I'd look first

**Closing your account.** Its relief rate is 21.2%, about 11 points under the 32.3% average, and it makes up 7.6% of card issuer complaints. The other three are only one to three points under the average, so they matter mainly because of their size.

This is a place to investigate, not a conclusion. A low relief rate doesn't prove the company was wrong, and the data can't say why relief is low. A team would read the case notes to find out.

## What this does not show

- **Relief is not the same as resolved.** It means the company reported giving money or a fix. It doesn't show the issue was solved or the customer was satisfied, and the company chooses the category itself.
- **"Closed with explanation" doesn't mean the company was right.** The allegations in a complaint aren't verified, so some of these closures may be fair.
- **No satisfaction measure.** The CFPB stopped collecting the "consumer disputed" field in 2017.
- **No customer counts, so volume is not performance.** Big companies get more complaints partly because they have more customers.
- **Complaints are not a representative sample,** and the data has nothing on business impact such as cost or churn.
- **I checked the top 30 company names** when deciding who counts as a bureau. The other 486 weren't reviewed one by one.

## Files

- `cfpb_complaints_analysis.sql`: every query, in order, with comments
- `CFPB_complaints_relief_rate_analysis.xlsx`: summary, issue comparison, card issuer focus, and my decision log

---

**Kingsley** | JK Analytics | [add your LinkedIn link]
