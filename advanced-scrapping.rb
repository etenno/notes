require 'open-uri'
require 'nokogiri'
require 'csv'
require "net/http"
require 'webdrivers'
require "watir"
​
# NOTE: install Selenium first (follow watir tutorial)
​
BROWSER = Watir::Browser.new :chrome
​
# HOW TO USE WATIR:
# BROWSER.goto url_string
  # => take the browser and go to the url
​
# send to NOKOGIRI:
# current_page = Nokogiri::HTML.parse(BROWSER.html)
​
​
#
details_array = []
​
# ==========================================================================
#                      USEFUL METHODS
# ==========================================================================
​
  # THIS METHOD CHECKS IF URL IS VALID
  def url_exist?(url_string)
    puts "Attempting #{url_string}"
    url = URI.parse(url_string)
    req = Net::HTTP.new(url.host, url.port)
    # UNCOMMENT LINE BELOW FOR HTTPS websites.
      # req.use_ssl = (url.scheme == 'https')
    path = url.path unless url.path.nil?
    res = req.request_head(path || '/')
    if res.kind_of?(Net::HTTPRedirection)
      return true # Go after any redirect and make sure you can access the redirected URL
    else
      ! %W(4 5).include?(res.code[0]) # Not from 4xx or 5xx families
    end
  rescue Errno::ENOENT
    false #false if can't find the server
  rescue URI::InvalidURIError
    false #false if URI is invalid
  rescue SocketError
    false #false if Failed to open TCP connection
  rescue Errno::ECONNREFUSED
    false #false if Failed to open TCP connection
  rescue Net::OpenTimeout
    false #false if execution expired
  rescue OpenSSL::SSL::SSLError
    false
  end
​
​
  def login_if_needed(current_page)
    # USE NOKOGIRI LOGIC TO FIND LOGIN DIV & inputs
    login_needed = current_page.search('div.need-login').text
​
    if login_needed != ""
      puts "NEED TO LOGIN!"
      sleep(4)
      # BROWSER.<html_element>.<action>
      # BROWSER.a.click
      BROWSER.div(:class => "need-login").a.wait_until(&:present?).click
      sleep(2)
      # input type='text'
      BROWSER.text_field(id:"username").wait_until(&:present?).set("18657407290")
      BROWSER.text_field(id:"rawpassword").wait_until(&:present?).set("turtlesrock")
​
      BROWSER.input(id: 'btnlogin').wait_until(&:present?).click
    end
  end
​
  def parse_one(page)
    # ALL YOUR NOKOGIRI PARSING LOGIC HERE
    # REPLACE W/ YOUR NOKO LOGIC
    app_materials_data_set = page.search('div.data-table[6] table tbody tr')
    school_hash = {}
    school_hash["name"] = page.search('h3.en').text.strip
    school_hash["cn_name"] = page.search('h2.zh').text.strip
    school_hash["logo_link"] = page.search('div.school-avatar span img').attr('src').value
    school_hash["TOEFL?"] = app_materials_data_set[0].search('td[2]').text
    school_hash["TOEFL_Note"] = app_materials_data_set[0].search('td[3]').text
    school_hash["IELTS?"] = app_materials_data_set[1].search('td[2]').text
    school_hash["IELTS_Note"] = app_materials_data_set[1].search('td[3]').text
    school_hash["SAT/ACT?"] = app_materials_data_set[2].search('td[2]').text
    school_hash["SAT/ACT_Note"] = app_materials_data_set[2].search('td[3]').text
    school_hash["SAT2?"] = app_materials_data_set[3].search('td[2]').text
    school_hash["SAT2_Note"] = app_materials_data_set[3].search('td[3]').text
    school_hash["Recs?"] = app_materials_data_set[4].search('td[2]').text
    school_hash["Recs_Note"] = app_materials_data_set[4].search('td[3]').text
    school_hash["Interview?"] = app_materials_data_set[5].search('td[2]').text
    school_hash["Interview_Note"] = app_materials_data_set[5].search('td[3]').text
    p school_hash
    return school_hash
  end
​
  def scrape_one(i)
    link = "http://www.shenqing.me/sqcollege/collegedetails_apply.jsp?id=#{i}"
​
    # NOTE:  uncomment line in url_exist? if visiting https: site.
    return "NEXT" unless url_exist?(link)
​
    # VISIT PAGE
    BROWSER.goto link
    current_page = Nokogiri::HTML.parse(BROWSER.html)
​
    # LOGIN TO ACCOUNT
    login_if_needed(current_page)
​
    # SETUP PAGE FOR NOKOGIRI
    page = Nokogiri::HTML.parse(BROWSER.html)
​
    # Check if page is showing their generated error page
    if page.search('div.error-num').text.strip == "500"
      return "NEXT"
    else
      # PARSE INFO INTO ORGANIZED HASH W/ NOKOGIRI
      return parse_one(page)
    end
  end
​
  def hashes_to_csv(arr=[])
    # arr is array of hashes:  [{},{},{},....]
    CSV.open("shenqing_me_app_materials.csv", "wb") do |csv|
      csv << arr.first.keys # adds the attributes name on the first line
      arr.each do |hash|
        csv << hash.values
      end
    end
  end
​
​
  (101..350).each do |i|
    # ---------------------------------------------------
    # SCRAPE PAGE W/ ID = i
    h = scrape_one(i)
    details_array <<  h unless h == "NEXT"
    # ---------------------------------------------------
    # SAVE ALL PAGES SCRAPED SO FAR...
    # (important to save inside the loop after each time.)
    # (if wifi signal breaks, you won't need to start from 0)
    hashes_to_csv(details_array)
    # ---------------------------------------------------
​
    # ---------------------------------------------------
    # WAIT TO SATISFY ROBOTS.TXT or DON'T.  UP TO YOU.
    # sleep(4)
    # ---------------------------------------------------
  end
​
