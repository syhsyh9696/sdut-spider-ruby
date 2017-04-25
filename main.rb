# encoding:utf-8

require 'rest-client'
require 'reverse_markdown'
require 'nokogiri'
require 'json'
require 'pp'

def sdut_get(pid)
    baseurl = "http://www.sdutacm.org/onlinejudge2/index.php/Home/Index/problemdetail/pid/#{pid}.html"

    begin
        response = RestClient.get baseurl
    rescue Exception => e
        p "connent error #{pid}"
    end

    doc = Nokogiri::HTML(response.body)

    host = "http://www.sdutacm.org"
    doc.search('//a').each do |row|
        row.attributes['href'].value = host + row.attributes['href'].value if row.attributes['href'] != nil
    end

    doc.search('//img').each do |row|
        row.remove if row.attributes['alt'].value == "tex2html_wrap_inline75"
        row.attributes['src'].value = host + row.attributes['src'].value if row != nil
    end

    # find all types of the website
    result = Hash.new
    doc.search('//h4').each do |row|
        result["#{row.children.text}"] = nil
    end

    problem_content = Array.new
    doc.search('//div[@class="prob-content"]').each do |row|
        problem_content << ReverseMarkdown.convert(row.children.to_s.gsub("\u00A0", "")).strip
    end

    result.each do |index, value|
        result[index] = problem_content.delete(problem_content.first)
    end

    doc.search('//div[@class="prob-info"]/span').each do |row|
        problem_content << row.text.split(":")[-1].gsub("MS", "").gsub("KB", "").gsub("\u00A0", "")
    end
    result[:Timlimit] = problem_content[0]
    result[:Memorylimit] = problem_content[1]

    result = result.to_json
    io = File.open("./problems/#{pid}.json", "w")
    io << result
    io.close
end

def sdut_pagenum_max
    baseurl = "http://www.sdutacm.org/onlinejudge2/index.php/Home/Index/problemlist"

    begin
        response = RestClient.get baseurl
    rescue Exception => e
        p "get problem id error"
        retry
    end

    doc = Nokogiri.HTML(response.body)
    doc.search('//a[@class="end"]')[0].children.text.to_i
end

def sdut_pid_max(page)
    baseurl = "http://www.sdutacm.org/onlinejudge2/index.php?m=&c=Index&a=problemlist&p=#{page.to_s}"

    begin
        response = RestClient.get baseurl
    rescue Exception => e
        retry
    end

    doc = Nokogiri(response.body)
    doc.search('//table[@class="table table-bordered table-hover"]/tbody/tr[last()]/td[1]').children.text.to_i
end

def thread(max_num)
    offset = max_num / 1000
    thread = Array.new
    1.upto(offset) do |n|
        temp = Thread.new{
            first_num = 1000 * n
            if max_num - first_num >= 1000
                first_num.upto(first_num + 999) do |pid|
                    sdut_get(pid)
                end
            else
                first_num.upto(max_num) do |pid|
                    sdut_get(pid)
                end
            end
        }
        thread << temp
    end

    thread.each { |n| n.join }
end

#sdut_get(1059)
thread(sdut_pid_max(sdut_pagenum_max).to_i)
