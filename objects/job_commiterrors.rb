# encoding: utf-8

# Copyright (c) 2016-2017 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Job that posts exceptions as commit messages.
# API: http://octokit.github.io/octokit.rb/method_list.html
#
class JobCommitErrors
  def initialize(name, github, commit, job)
    @name = name
    @github = github
    @commit = commit
    @job = job
  end

  def proceed
    @job.proceed
  rescue Exception => e
    done = @github.create_commit_comment(
      @name, @commit,
      "I wasn't able to retrieve PDD puzzles from the code base (if you \
think that it's a bug on your our side, please submit it to \
[yegor256/0pdd](https://github.com/yegor256/0pdd/issues)):\n\n\
```\n#{e.message}\n#{e.backtrace.join("\n")}\n```"
    )
    puts "Comment posted about an error: #{done['html_url']}"
    raise e
  end
end
