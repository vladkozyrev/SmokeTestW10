## =======================================
## ======== BVT(Smoke) Test===============
## ======= 10-01-2009 by AA===============
## =======================================
class SmokeTest < AdifyTest
  include AdifyFileFunctions

  def initialize(env)
    super
    $logger = AdifyLogger.new(File.join(@log_file_path,"Log_#{TestName}"),env)
    $logger.test TestName
    ## --------- Initialization of business objects
    net_builder1 = NetBuilder.new($qa_server.get_hash_from_db('NetBuilders',"net_smoke_test"), $timeStamp)
    publisher1 = Publisher.new(net_builder1,$qa_server.get_hash_from_db('Publishers',"publisher1"), $timeStamp)
    site1 = Site.new(publisher1,$qa_server.get_hash_from_db('Sites',"site_1"),$timeStamp)
    site2 = Site.new(publisher1,$qa_server.get_hash_from_db("Sites","site_2"),$timeStamp)
    ad_space1 = AdSpace.new($qa_server.get_hash_from_db('AdSpaces',"ad_Space_1"))
    site1.addAdSpace(ad_space1)
    campaign1 = Campaign.new(net_builder1,$qa_server.get_hash_from_db('Campaigns',"campaig_smoke_test"), $timeStamp)
    Ad.new(campaign1,$qa_server.get_hash_from_db('Ads',"ad_1"))
    Ad.new(campaign1,$qa_server.get_hash_from_db('Ads',"ad_2")) 
    line1 = LineItem.new(campaign1,$qa_server.get_hash_from_db('Lines',"line_smoke_test1"), $timeStamp)
    ## === point locationList for every line item to correct adspace objects
    campaign1.lines.each {|line|
      line.locationList.each_with_index { |adspace,i|
        tempadspace = site1.adSpaces.find{|as| as.bo_name == adspace.bo_name}
        line.locationList[i]  = tempadspace if tempadspace
      }
    }
    ##---Test flow----------------------------------------------------
    AdifyMap.set_env_name(env)    # set AdifyMap class vbl, and Watir::IE class vbl
    $app = AdifyPlatformTool.new  # instance of the PlatformTool page on the site
    $app.get_credentials          # $qa_server gets uid, pwd, ownerEmail from QAAutomation db for current USER
    owner_email = $app.ownerEmail

   ## ie = Watir::IE.new
    ie = Watir::Browser.new :chrome
  # profile = Selenium::WebDriver::Firefox::Profile.new
 # profile['browser.download.dir'] = "/tmp/webdriver-downloads"
 # profile['browser.download.folderList'] = 2
 # profile['browser.helperApps.neverAsk.saveToDisk'] = "application/pdf"
 # profile.native_events = false
    
  #  ie = Watir::Browser.new :firefox  ##, :profile=> profile
    ie.login($app.uid,$app.pwd)
    
   # sleep 0
   # ie.span(:id,/DialogContent_SaveDialog_Save_out/).links[0].click
    
    net_builder1.email        = owner_email  # use email of person running smoketest
    net_builder1.contactEmail = owner_email
    ie.create_net(net_builder1)
    publisher1.email = owner_email
    ie.create_publisher(publisher1)
    ie.set_pub_approval_status(publisher1,'Approved')
    sleep 5
    ie.create_site(publisher1, site1)
    ie.create_campaign(campaign1)
    ie.sign_out

  #######################################################
  #                                                     #
  #  Create Html file holding all ad tags for site1     #
  #                                                     #
  #######################################################
  
    url_site = SiteURL.strip + 'site' + $timeStamp + '.html'
    site_file = File.new(url_site,"w")
    site_file.puts "<h1> This file was created by Smoke Test on #{$timeStamp} </h1>"
    site1.adSpaces.each do |adSpace|
      site_file.puts "<h2> Ad Space: <#{adSpace.name}> size: <#{adSpace.size}> type: #{adSpace.type} </h2>"
      site_file.puts adSpace.tag
    end
    $logger.info "File #{url_site} has been created"
    site_file.close
    url_site = SiteHTTP.strip + 'site' + $timeStamp + '.html'

    ie1 =  Watir::Browser.new :chrome
    ie1.goto url_site           # put up ad page

  #######################################################
  #                                                     #
  #   Get pub pw from email, login, and create site2    #
  #                                                     #
  #######################################################

#   pwd = ie.getPubPassword(net_builder.networkName, publisher1.name)
    pwd = ie.getPubPassword(net_builder1.networkName)
    $logger.testcase("FATAL error - no pub pw",0) if pwd.nil?
    
    ie.login(publisher1.name, pwd)
    $app = UpDateSignIn.new
    ie.fill_out_UpdateSignIn(publisher1)
    ie.link(:id, /NoPayout1099Dialog_Cancel/).click if ie.link(:id,/NoPayout1099Dialog_Cancel/).exists?
    ie.link(:id,/#{$app.linkSitesId}/,103).click
    ie.link(:id,/#{$app.linkCreateSiteButId}/,2103).click
    ie.fill_out_create_site site2
#    if env =~ /qa|staging/i
#      ie.fill_out_create_site_new site2
#    else
#      ie.fill_out_create_site site2
#    end
    ie.link(:id,/#{$app.linkSubmitBtnId}/,104).click
    sleep 2
    ie.link(:id,/#{$app.linkReturnToDashBtnId}/,102).click
    if ie.text.include?site2.name
      $logger.testcase("Site <#{site2.name}> has been created by publisher <#{publisher1.name}>has been found on pub's dashboard page",0)
    else
      $logger.testcase("Site <#{site2.name}>that has been created by publisher <#{publisher1.name}>hasn't been found on pub's dashboard page",1)
    end
    ie.sign_out

  #######################################################
  #                                                     #
  #   Login as publisher, find buys, Ads, etc.          #
  #                                                     #
  #######################################################

    $app = AdifyPlatformTool.new
    ie.login(net_builder1.name, net_builder1.password)
    sleep 3
    $app = NBDashboard.new
    ie.link(:text,/#{$app.linkSitesItext}/,221).click
    ie.span(:id,"ctl00_PageTaskContent_SitesTasks_title").click
    sleep 1
    ie.link(:id,/#{$app.linkManageSiteAppId}/,222).click
    ie.link(:text,/#{$app.linkPendingItext}/,222).click
    if (ie.table(:id,/#{$app.tableSitesPendingId}/).exists?)&&(ie.table(:id,/#{$app.tableSitesPendingId}/).text.include?site2.name)
      $logger.testcase("Site <#{site2.name}> has been found on NB's <#{$app.name}> page",0)
    else
      $logger.testcase("Site <#{site2.name}> hasn't been found on NB's <#{$app.name}> page",1)
    end
    50.times do |i|
     ($logger.testcase("MediaBuy <#{line1.lineItemID}> has been found on AdServer mode page<#{getDEforMediaBuy(line1.lineItemID)}>",0); break) if $app.get_mediabuy_status_from_de(line1.lineItemID) ## getMediaBuyStatus(line1.lineItemID, 'ReasonSuccess')
      sleep 30
      $logger.info "Waiting for AdServer updating Elapsed time <#{i*30}sec> MediaBuyId:<#{line1.lineItemID}> AdServer <#{$app.decisionEngine1}>"
    end
    $logger.testcase("MediaBuy Id:<#{line1.lineItemID}> hasn't been found on AdServer <#{getDEforMediaBuy(line1.lineItemID)}mode page>",1) unless $app.get_mediabuy_status_from_de(line1.lineItemID, 'ReasonSuccess')
    site1.adSpaces.each do |adSpace|
      ## looking for ads that could be served on this ad space
      expected_ads = Array.new
      expected_ads = adSpace.getServingAds campaign1
      $logger.info "Verification for ad space name:#{adSpace.name} , id: #{adSpace.o_Id} , size: #{adSpace.size}"
      3.times {ie1.refresh; sleep 1}
      if expected_ads.find {|ad| ie1.text.include?(ad.body)}
        $logger.testcase("Ad has been served",0)
        $logger.info("Smoketest is a PASS thus far--please check reports manually for impressions later")
      elsif not expected_ads.empty?
        $logger.testcase("Creative hasn't been served. Please, troubleshoot platform manually",1)
      end
    end
  end # initialize(env)
end #SmokeTest
