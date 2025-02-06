require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'

# Initialize the logger
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://www.devonport.tas.gov.au/building-development/planning/advertised-planning-permit-applications/'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS devonport (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s

# Step 4: Extract data for each document from each row in the table
doc.css('.wpfd-search-result tbody tr').each do |row|  # Ensure we are iterating over all rows
  title_reference = row.at_css('.wpfd_downloadlink')['title']
  
  # Split the title into council_reference, address, and description
  council_reference = title_reference.split(' - ').first
  address = title_reference.split(' - ')[1]
  description = title_reference.split(' - ')[2..-2].join(' - ')
  document_description = row.at_css('.wpfd_downloadlink')['href']
  date_received = row.at_css('.file_created').text.strip
  #date_received = Date.strptime(date_received, "%Y %B %d").to_s

  on_notice_to = title_reference.match(/ends (\d{1,2} [A-Za-z]+ \d{4})/)&.captures&.first
  on_notice_to = Date.strptime(on_notice_to, "%d %B %Y").to_s

  # Log the extracted data for debugging purposes
  logger.info("Extracted Data: Council Reference: #{council_reference}, Address: #{address}, Description: #{description}, Date Received: #{date_received}, On Notice To: #{on_notice_to}, Document URL: #{document_description}")

  # Step 5: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM devonport WHERE council_reference = ?", council_reference)

  if existing_entry.empty? # Only insert if the entry doesn't already exist
    # Save data to the database
    db.execute("INSERT INTO devonport (description, date_received, document_description, council_reference, on_notice_to, address, date_scraped) 
      VALUES (?, ?, ?, ?, ?, ?, ?)", [description, date_received, document_description, council_reference, on_notice_to, address, date_scraped])

    logger.info("Data for #{council_reference} saved to database.")
  else
    logger.info("Duplicate entry for document #{council_reference} found. Skipping insertion.")
  end
end

# Finish
logger.info("Data has been successfully inserted into the database.")
