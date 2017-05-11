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
        retry
    end

    return nil if response == nil
    doc = Nokogiri::HTML(response.body)

    host = "http://www.sdutacm.org"
    doc.search('//a').each do |row|
        if row.attributes['href'] != nil
            row.attributes['href'].value = host + row.attributes['href'].value if row.attributes['href'].value.index("http") == nil
        end
    end

    doc.search('//img').each do |row|
        next if row.attributes['alt'] == nil
        row.remove if row.attributes['alt'].value == "tex2html_wrap_inline75"
        row.attributes['src'].value = host + row.attributes['src'].value if row != nil && row.attributes['src'].value.index("http") == nil
    end

    # find all types of the website
    result = Hash.new
    doc.search('//h4').each do |row|
        result["#{row.children.text}"] = nil
    end

    return nil if result.empty?

    problem_content = Array.new
    doc.search('//div[@class="prob-content"]').each do |row|
        temp = row.children.to_s
        problem_content << temp.gsub("\u00A0", " ")
    end

    result.each do |index, value|
        result[index] = problem_content.delete_at(0)
    end

    result.each do |index, value|
        result[index] = ReverseMarkdown.convert(value, unknown_tags: :bypass).strip if index != "Example Input" && index != "Example Output"
    end

    #result['Example Input'].gsub("<pre>", "").gsub("</pre>", "").rstrip if result['Example Input'] != nil
    #result['Example Output'].gsub("<pre>", "").gsub("</pre>", "").rstrip if result['Example Output'] != nil
    result['Example Input'] = Nokogiri::HTML.parse(result['Example Input']).text.rstrip
    result['Example Output'] = Nokogiri::HTML.parse(result['Example Output']).text

    doc.search('//div[@class="prob-info"]/span').each do |row|
        problem_content << row.text.split(":")[-1].gsub("MS", "").gsub("KB", "").gsub("\u00A0", "")
    end
    result[:Timlimit] = problem_content[0]
    result[:Memorylimit] = problem_content[1]
    result[:title] = doc.search('//h3').text.strip

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

#sdut_get(1018)
thread(sdut_pid_max(sdut_pagenum_max).to_i)
