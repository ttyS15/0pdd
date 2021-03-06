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

require 'nokogiri'
require_relative 'safe_tickets'

#
# Puzzles in XML/S3
#
class Puzzles
  def initialize(repo, storage)
    @repo = repo
    @storage = storage
  end

  def deploy(tickets)
    # @todo #3:30min It's not really effective to always save the XML
    #  document back to storage, even when it was not really modified. Would
    #  be much better to check whether any modifications have been made
    #  and skip that SAVE() operation.
    saved(
      covered(
        saved(
          group(
            submit(
              close(
                join(@storage.load, @repo.xml),
                tickets
              ),
              tickets
            )
          )
        ),
        SafeTickets.new(tickets)
      )
    )
  end

  private

  def saved(xml)
    @storage.save(xml)
    xml
  end

  def join(before, snapshot)
    target = before.xpath('/puzzles')[0]
    snapshot.xpath('//puzzle').each do |p|
      p.name = 'extra'
      target.add_child(p)
    end
    target['date'] = snapshot.xpath('/puzzles/@date')[0].to_s
    target['version'] = VERSION
    before
  end

  def group(xml)
    Nokogiri::XSLT(File.read('assets/xsl/group.xsl')).transform(
      Nokogiri::XSLT(File.read('assets/xsl/join.xsl')).transform(xml)
    )
  end

  def submit(xml, tickets)
    Nokogiri::XSLT(File.read('assets/xsl/to-submit.xsl'))
      .transform(xml)
      .xpath('//puzzle')
      .map { |p| { issue: tickets.submit(p), id: p.xpath('id').text } }
      .reject(&:nil?)
      .reject { |p| p[:issue].nil? }
      .each do |p|
        xml.xpath("//extra[id='#{p[:id]}']")[0].add_child(
          "<issue href='#{p[:issue][:href]}'>#{p[:issue][:number]}</issue>"
        )
      end
    xml
  end

  # @todo #41:30min Let's post notification messages to tickets where
  #  other puzzles were waiting for the resolution of this one. Let's update
  #  them with a summary information of what is left.
  def close(xml, tickets)
    Nokogiri::XSLT(File.read('assets/xsl/to-close.xsl'))
      .transform(xml)
      .xpath('//puzzle')
      .each { |p| tickets.close(p) }
    xml
  end

  def covered(xml, tickets)
    if tickets.safe
      xml.xpath('//puzzle[@alive="false" and issue and issue!="unknown"]')
        .each { |p| tickets.close(p) }
      xml.xpath('//puzzle[@alive="true" and (not(issue) or issue="unknown")]')
        .map { |p| { issue: tickets.submit(p), id: p.xpath('id').text } }
        .reject(&:nil?)
        .reject { |p| p[:issue].nil? }
        .each do |p|
          node = xml.xpath("//puzzle[id='#{p[:id]}']")[0]
          node.search('issue').remove
          node.add_child(
            "<issue href='#{p[:issue][:href]}'>#{p[:issue][:number]}</issue>"
          )
          saved(xml)
        end
    end
    xml
  end
end
