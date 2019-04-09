Want to contribute? Great! First, read this page. This document serves as a guide for you to contribute to the Android Starlark Rules productively and efficiently in partnership with Google.


### Prerequisite

1. Before we can use your code, you must sign the [Google Individual Contributor License Agreement](https://developers.google.com/open-source/cla/individual?csw=1)
(CLA), which you can do online.

   1. The CLA is necessary mainly because you own the copyright to your changes, even after your contribution becomes part of our codebase, so we need your permission to use and distribute your code. We also need to be sure of various other things — for instance that you'll tell us if you know that your code infringes on other people's patents. You don't have to sign the CLA until after you've submitted your code for review and a member has approved it, but you must do it before we can put your code into our codebase.
   
1. Contributions made by corporations are covered by a different agreement than
the one above, the
[Software Grant and Corporate Contributor License Agreement](https://cla.developers.google.com/about/google-corporate).

### Contribution process

1. Create a GitHub issue following the steps below for filing bugs and feature requests.

1. Determine whether your contribution requires a lightweight change or a more complex change to the codebase.

   1. Lightweight change: Simple bug fixes, small updates, internal cleanup, etc.
   
   1. Complex change: New features, large scale bug fixes, major refactoring, etc.

1. If you have determined your change as lightweight, then you can skip to Step 7. You may be asked to follow the full process if your pull request reviewer believes a more thorough design is needed. Follow all steps if you have a more complex change.

1. Author a brief contribution proposal document and submit to android-rules-contrib@google.com for review. Please use the following [template](https://docs.google.com/document/d/14PJfIvFkHQMuQzAovtVGavdsXjxMJ8O7dxDeatX1HLM/edit?usp=sharing) for the document outlining:

   1. Problem Statement
   
   1. Proposed Solution
   
   1. Alternative Considerations if any

1. Our team will assign a reviewer and provide questions/comments on the design document.

1. After resolving the comments, the design document reviewer will make a decision on how to move forward. Possible outcomes may include:

   1. Approved - you may move to the next step.

   1. Rejected - there is an alternative pre-existing solution.

   1. Rejected - appropriate solution is not present.

1. Fork the repository to develop and test your code locally.
   
   1. Don’t forget to add tests. Run the existing tests with bazel test //...

   1. Update any relevant documentation after implementation.

1. Issue a Pull Request and then wait for the upstream developers to review. You may be asked to make some changes before your PR is merged in.

1. All submissions, including submissions by project members, require review.
Once everything looks good, your changes will be merged.  Our continuous integration bots will test your change automatically on supported platforms.

1. Close the corresponding GitHub issue.

### Filing Bugs & Feature Requests

1. Create a new issue on the GitHub repository if you believe you’ve encountered a bug or have a feature request.

1. If you are filing a bug, give it an appropriate title & be sure to include the following in the description:
   
   1. Expected behavior
   
   1. Current behavior
   
   1. Steps to reproduce
   
   1. Context, logs, failure information

1. If you are filing a feature request, give it an appropriate title & be sure to include the following in the description:
   
   1. Objective
   
   1. Goals

1. When you're finished, click Submit new issue.

### Communication Channels

Please feel free to reach out if there are any questions, comments, or feedback you would like to communicate. We will be actively monitoring the following:
   
   1. Emails to android-rules-contrib@google.com
   
   1. Messages to #android channel in [Bazel's Slack](https://bazelbuild.slack.com). Sign-up [here](https://bazel-slackin.herokuapp.com).
