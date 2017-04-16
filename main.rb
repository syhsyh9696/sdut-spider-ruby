# encoding:utf-8

require 'rest-client'
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

    # find all types of the website
    result = Hash.new
    doc.search('//h4').each do |row|
        result["#{row.children.text}"] = nil
    end

    problem_content = Array.new
    doc.search('//div[@class="prob-content"]/.').map do |row|
        problem_content << row.children[1].text if row.children[1] != nil
    end

    result.each do |index, value|
        result[index] = problem_content.delete(problem_content.first)
    end

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

thread(sdut_pid_max(sdut_pagenum_max).to_i)
