class SmokeTestNew < AdifyTest
  include AdifyFileFunctions
  def initialize(env)
    super
    @start = Time.now.to_f
    $logger = AdifyLogger.new(File.join(@log_file_path,"Log_#{TestName}"),env)
    $logger.test TestName
    ## --------- Initialization of business objects ------
    @net_builder1 = NetBuilder.new($qa_server.get_hash_from_db('NetBuilders',"net_smoke_proposal"), $time_stamp)
    @publisher1 = Publisher.new(@net_builder1,$qa_server.get_hash_from_db('Publishers',"aa_proposal"), $time_stamp)
    @site1 = Site.new(@publisher1,$qa_server.get_hash_from_db('Sites',"proposal_site_1"),$time_stamp)
    @site1.url = @site1.url.sub(".","#{$time_stamp}.")
    @site1.name = @site1.name + $time_stamp
    @site1.smart_tag = @net_builder1.smart_tag
    @site2 = Site.new(@publisher1,$qa_server.get_hash_from_db("Sites","proposal_site_2"),$time_stamp)
    @site2.url = @site2.url.sub(".","#{$time_stamp}.")
    @site2.name = @site2.name + $time_stamp
    @site2.smart_tag = @net_builder1.smart_tag
    @ad_space1 = AdSpace.new($qa_server.get_hash_from_db('AdSpaces',"ad_Space_1"))
    @ad_space2 = AdSpace.new($qa_server.get_hash_from_db('AdSpaces',"ad_Space_4"))
    @site1.addAdSpace(@ad_space1)
    @site2.addAdSpace(@ad_space2)
    @campaign1 = Campaign.new(@net_builder1,$qa_server.get_hash_from_db('Campaigns',"campaig_smoke_test"), $time_stamp)
    Ad.new(@campaign1,$qa_server.get_hash_from_db('Ads',"proposal_ad_1"))
    Ad.new(@campaign1,$qa_server.get_hash_from_db('Ads',"proposal_ad_2"))
    #  @line1 = LineItem.new(@campaign1,$qa_server.get_hash_from_db('Lines',"line_smoke_test1"), $time_stamp)
    ## === point locationList for every line item to correct adspace objects
    #@campaign1.lines.each {|line|
    #  line.locationList.each_with_index { |adspace,i|
    #    tempadspace = @site1.adSpaces.find{|as| as.bo_name == adspace.bo_name}
    #    line.locationList[i]  = tempadspace if tempadspace
    #  }
    #}
    LineItem.new(@campaign1, $qa_server.get_hash_from_db('Lines',"line_prop_01"))
    LineItem.new(@campaign1, $qa_server.get_hash_from_db('Lines',"line_prop_02"))
    LineItem.new(@campaign1, $qa_server.get_hash_from_db('Lines',"line_prop_03"))
    @campaign1.lines[2].name = "#{@campaign1.lines[2].name}#{$time_stamp}"
    #  line1.campaign, line2.campaign,line3.campaign = @campaign1
    #lines[1].name = "ROS_300x250"
    #lines[2].name = "ROS_728x90"
    @proposal = Proposal.new($qa_server.get_hash_from_db('Proposal',"smoke_test_p_1"), $time_stamp)
    @proposal_li = ProposalItem.new($qa_server.get_hash_from_db('ProposalItem',"smoke_test_pli_1"), $time_stamp)
    @proposal_li_2 = ProposalItem.new($qa_server.get_hash_from_db('ProposalItem',"smoke_test_pli_2"), $time_stamp)
    @proposal_li.start_date = @proposal_li_2.start_date = Time.now.strftime("%m/%d/%Y")
    @proposal_li.end_date  = @proposal_li_2.end_date = (Time.now+2592000).strftime("%m/%d/%Y")
    @campaign1.name = @proposal.name

    ##---Test flow---------------------------------------------------
    run_proposal_test(env)
  end
  def run_proposal_test(env)
    $logger.info("Starting proposal test")
    AdifyMap.set_env_name(env)    # set AdifyMap class vbl, and Watir::IE class vbl
    $app = NetworkCS.new  # instance of the PlatformTool page on the site
    $app.get_credentials          # $qa_server gets uid, pwd, ownerEmail from QAAutomation db for current USER
    @proposal_li_2.owner_email = $app.ownerEmail
    ##  ie = Watir::IE.attach(:url,/qa-cs-1/)
    ## ie = Watir::IE.attach(:url, /#{env.downcase}-cs-1/)
    ## ie = Watir::IE.attach(:url,/staging-cs-1/)
    ##  ie.link(:href,/#{$app.linkProposalHref}/,8100).click
    ##   ie = Watir::Browser.new :ie
    
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.timeout = 600 # seconds – default is 60
    ie = Watir::Browser.new :chrome, :switches => %w[--ignore-certificate-errors --disable-popup-blocking --disable-translate]
    ie.login($app.uid,$app.pwd)
    ie.impersonate_net_by_name(@net_builder1)
## =================  clean up start ==================

   if $CLEANUP 
   $Number_Sites = 14   # number of sites 14
     ie.click_sites_tab("Sites")
     ie.enter_search_text((@site1.name)[0,6]||str)
     ie.sites_click_search()
     ie.sites_cleanup_sitestable()
     ie.click_sites_tab("Network")
   end 
 
  ## =================  clean up end ==================    
    ie.div(:text,"Network name").when_present(30)
    ie.create_publisher(@publisher1) ## change doc mode to standard
    sleep 5
#    ie.link(:id,"ctl00_appHeader_topTabs_SitesTabDefault").click
    ie.set_pub_approval_status(@publisher1,'Approved')
    sleep 5
    ie.look_up_pub_on_site_and_pub_page(@publisher1)
    ie.create_site(@publisher1, @site1)
 #   Watir::Wait.until { execute_script("return jQuery.active") == 0 }
    sleep 4
 #  ie.text_field(:id,/SiteTableSearchBox/).set @site1.name.split(" ").last
 #  ie.button(:id,/SiteTableSearchButton/).click
 #   Watir::Wait.until { execute_script("return jQuery.active") == 0 }
 #   sleep 4
    ## 60.times{ break if ie.link(:text,@publisher1.name).exists?; sleep 1  * GlobalAdjustedSleepTime}
 #   ie.link(:text,@site2.name).wait_until_present(60)
    ie.create_site(@publisher1, @site2)
  #  sleep 4
    ie.div(:id,/appHeader_topTabs/).link(:text,"Network").click
    sleep 2
    begin
    ie.div(:id,/appHeader_topTabs/).link(:text,"Proposals").click
    rescue Exception => e ## Timeout::Error => e
      $logger.info("Proposal Tab did not load: #{e}")
      sleep 30
      ie.div(:id,/appHeader_topTabs/).link(:text,"Proposals").click
    end  
   ##  $app = Proposals.new
   ##  ie.wait_until_ready(:id,"ctl00_ctl00_BodyContent_BodyContent_ProposalLineItemTable")
    sleep 5 
    ie.link(:id,/BodyContent_BodyContent_AddProposal/,8200).click
   ## ie.wait_until_ready(:id,/TabSet_ProposalDetails_EditCategoryButton/)
   # ie.get_available_values_for_proposal_193(@proposal,@net_builder1) if AdifyTest.ruby_version >= 190
   # ie.get_available_values_for_proposal_187(@proposal,@net_builder1) if AdifyTest.ruby_version < 190
    ie.fill_out_proposal_details_fast(@proposal)
    $logger.info("Saving order")
    ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_SaveSyncButton",8200).click ## check if browser in "document standard mode"
   # ie.link(:text, /#{$app.linkTabOrderText}/,8200).click
    sleep 7
    ie.link(:text, "Order",8200).click
    sleep 5
    ie.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ddSeachType",8200).option(:value,"CDS_Local").select
   ## ie.wait_until_ready(:id,/btnLocalRefresh/,8200)
    ## ie.select_list(:id,/#{$app.slTabSetddSeachType}/).option(:value,"CDS_National").select
    ie.wait_until_ready(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_btnLocalRefresh")
    ie.link(:text,"Refresh Inventory Data").click
    sleep 5
    ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_btnSearch",8200).click
    ## ie.wait_until_ready(:id,/dtInventory/)  ## search result table is loaded
    ie.set_site_search_criteria(@site2)
    sleep 5
    ie.link(:text, "Site URL",8200).click  ## sort sites on the page to get my site on top of the list
    sleep 3    
  
#    ie = Watir::Browser.new :chrome
#    @site2.url = "http://aaaPSTest2_20140228_145533.com"
#    @proposal.name = "The smoketest proposal_20140228_145533"
#    sleep 0
      
    ie.select_site_for_proposal(@site2.url)  ## rows indexes should be +1
    ie.button(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_SetFlightButton",8200).click
    sleep 2
    ie.fill_in_flight_dialog(@proposal_li)
    sleep 2
    # Jeff Remove after 10.7 release
    if ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewButton").exists?
      ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewButton").click
      sleep 3
      ie.adhoc_dialog_fill_out_old(@proposal_li_2)      
    end
    if ie.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ddlCreateLineItems").exists?
      ie.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ddlCreateLineItems",8200).option(:value,"ExtendedReach").select
      ie.button(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_btnCreate",8200).click
      sleep 3
      ie.adhoc_dialog_fill_out(@proposal_li_2)
    end
#    sleep 3 ## ??
#    ie.adhoc_dialog_fill_out(@proposal_li_2)
    ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_SaveSyncButton").click
    sleep 10
    ie.div(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ctl00").link(:text,"All Flights").click
    ie.check_lines_for_flight_bulk_edit(@proposal_li)
    ie.button(:id,/ProposalEditor_ButtonAction/).click
    ## fill out bulk edit selected dialog
    sleep 5
    ie. bulk_edit_selected_dialog_fill_out(@proposal_li)
    ie.link(:id,"ctl00_ctl00_BodyContent_BodyContent_SaveSyncButton").click ## save proposal
    sleep 30
    ## ====     reload proposalsdetailsnew page
    ie.link(:id,"ctl00_ctl00_appHeader_topTabs_ProposalSubTab").click
    sleep 30 * GlobalAdjustedSleepTime
    if  ie.link(:text,"#{@proposal.name}").present? ##visible?
      ie.link(:text,"#{@proposal.name}").click
     else
       puts "Name is not visible"   ## vvv
     end
    sleep 15
    ## ==========================
    $app = ProposalDetailsNew.new
    ie.approve_proposal_fast
    sleep 0
    @campaign1.o_Id = ie.link(:href,/campaignId=/).attribute_value("href")[/campaignId=(\d*)/].sub!("campaignId=","")  ## getting campaign id from the link on "ProposalDetailsNew" page
    ie.link(:id,/BodyContent_hlCampaignLink/).click
    $app = CreateCampaign.new
    ie.select_partner_network(@campaign1.partnerNetworksList[0])
    sleep 12 * GlobalAdjustedSleepTime
    ie.add_creative_to_campaign(@campaign1.ads[0])
    ie.add_creative_to_campaign(@campaign1.ads[1])
    ie.link(:id,"ctl00_DialogContent_NotifyNetworksDialog_Send").click if ie.link(:id,"ctl00_DialogContent_NotifyNetworksDialog_Send").present?  ##visible?
  #  ie.link(:id,/#{$app.linkSaveBtnId}/,3101).click
    begin
       ie.link(:id,"ctl00_BodyContent_SaveButton",3102).click
       sleep 20
    rescue Exception => e  ## Timeout::Error => e
      $logger.info("Saving new campaign is taking too long time : #{e}")
      sleep 20
     end  
#    ie.text_field(:id,/CampaignListSearchTerms/).set @campaign1.name
#    ie.button(:id,/CampaignListSearchButton/).click
#    sleep 2
#    ie.link(:text,/#{@campaign1.name}/,3102).click
#    ##   sleep 5
    ie.div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    $app = LineItemPage.new
    sleep 10
    @table = ie.get_table_from_div(/clientTabView_LineItemTable/)
   # @table_lines = ie.get_table_from_div($app.divLineItemTblId)
    number_of_rows = @table.trs.length
    ##================== add Campaign LI ID column ================  Vlad added
    ie.element(:id, "ctl00_BodyContent_clientTabView_LineItemColumnSelector_ColumnSelectorButton").click  #
    if ie.element(:id, 'ctl00_DialogContent_ctl00_ctl14').option(:title, 'Campaign LI ID').exists?
      ie.element(:id, 'ctl00_DialogContent_ctl00_ctl14').option(:title, 'Campaign LI ID').click
      ie.element(:name, 'ctl00$DialogContent$ctl00$ctl16').click
      $logger.info("Column <Campaign LI ID> does not exist")
    else
      $logger.info("Column <Campaign LI ID> exists")
    end
    ie.element(:css, '#ctl00_DialogContent_ctl00_Save > em').click
    sleep 3
    ##================== end add Campaign LI ID column ================  
    for j in 1..number_of_rows-1
      r = @table[j]
      size_column_index = ie.find_column_index(@table,"Size")
      line_item_id_column_index = ie.find_column_index(@table,"Campaign LI ID")
      if r.tds.length > line_item_id_column_index && r[size_column_index].links.size > 0    
        @campaign1.lines.each { |l|  
          l.lineItemID = r.tds[line_item_id_column_index].text if r.text.include?(l.name) 
        }
        r[size_column_index].links[0].click
        sleep 8
        ## ie.checkbox(:id,/LineItemEditCreativesControl_BannerAdTable_CheckState_hcb/).set ##jeff
        ie.checkbox(:id,/LineItemEditCreativesControl_MixedAdTable_js_CheckState_cb/).set
        ie.link(:id,/LineItemCreativesDialog_Ok/).click
        sleep 7
      end
     ## @table = ie.get_table_from_div("ctl00_BodyContent_clientTabView_LineItemTable")
    end
    ## -------------------------------------------------------------

   #  get li id's  
    site_path = SiteURL.strip + env + "PSmokeTest" + $time_stamp + ".html"
    site_http = SiteHTTP.strip  + env + "PSmokeTest" + $time_stamp + ".html"
    site_file = File.new(site_path,"w")
    site_file.puts "<h3> This file was created by Proposal Smoke Test on #{$time_stamp} </h3>"
    ad_spaces = @site2.adSpaces + @site1.adSpaces
    ad_spaces.each do |ad_space|
      if not(ad_space.tag.empty? || ad_space.tag[/cdsTag.zones.as(\d*)/].empty?) ## and site.inventory_type.upcase == "LOCAL"
        ad_space.o_Id = ad_space_id = ad_space.tag[/cdsTag.zones.as(\d*)/].sub!("cdsTag.zones.as","")
#       size = ad_space.tag[/\"size\" : \"\d*x\d*\"/].sub!("\"size\" : ","")
        if ad_space.tag.include?("300x250")
          size = "300x250"
        end
         if ad_space.tag.include?("728x90")
          size = "728x90"
        end       
        if ad_space.tag.include?("300x50")
          size = "300x50"
        end        
        if ad_space.tag.include?("1x1")
          size = "1x1"
        end  
        if ad_space.tag.include?("160x600")
          size = "160x600"
        end        
          if ad_space.tag.include?("125x125")
          size = "125x125"
        end 
        case
        when ad_space.tag.include?("300x250") then media_buy_id = @campaign1.lines[0].lineItemID
        when ad_space.tag.include?("728x90") then media_buy_id = @campaign1.lines[1].lineItemID
        else
          media_buy_id = @campaign1.lines[1].lineItemID
        end
        site_file.puts "<h2> Ad Space Id<#{ad_space_id}> size <#{size}> mediabuy <#{media_buy_id}> </h2>"
        site_file.puts ad_space.tag.sub("cdsTag.keywords = null;", "cdsTag.zones.as#{ad_space_id}.keywords= { \"sr_k5\" : \"exadtag_#{@campaign1.o_Id}_#{media_buy_id}\" };\n cdsTag.keywords = null;")
      end
    end
    $logger.info "File #{site_path} has been created"
    site_file.close
    ie1 = Watir::Browser.new :chrome
    ie1.goto site_http        # put up ad page
    ## -------------------------------------------------------------------------------------------------
    ie.link(:id,/ConfirmButton/).click
    sleep 10
    if ie.link(:id,/ConfirmButton/).exists? && ie.link(:id,/ConfirmButton/).visible?
      ## if ie.text.index("At least one ad is required for each line item")
      ie.link(:id,"ctl00_BodyContent_SaveButton").click
      sleep 10
      ie.link(:id,/ConfirmButton/).click
    end  
    sleep 0
    ie.link(:id,/LiveButton/).click
    sleep 10
    ie.text_field(:id,/CampaignListSearchTerms/).set @campaign1.name
    ie.button(:id,/CampaignListSearchButton/).click
    sleep 2
    ie.link(:text,/#{@campaign1.name}/,3102).click
    ie.div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    $app = LineItemPage.new
    sleep 3

 #   ie.get_mediabuy_id(line1)
 #   ie.get_mediabuy_id(line2)
 #   ie.get_mediabuy_id(line3)
 #   sleep 3
    ie.link(:text,/Proposal *\d/).click
    sleep 8
  
#    sleep 0
#    url_site = SiteURL.strip + 'ProposalSmokeTest' + $time_stamp + '.html'
#    site_file = File.new(url_site,"w")
#    site_file.puts "<h3> This file was created by Proposal Smoke Test on #{$time_stamp} </h3>"
#    @site2.adSpaces.each do |ad_space|
#      unless ad_space.tag.empty?
#        ad_space_id = ad_space.tag[/cdsTag.zones.as(\d*)/].sub!("cdsTag.zones.as","")
#        case
#        when ad_space.tag.include?("300x250") then media_buy_id = @campaign1.lines[0].lineItemID
#        when ad_space.tag.include?("728x90") then media_buy_id = @campaign1.lines[1].lineItemID
#        else
#          media_buy_id = @campaign1.lines[2].lineItemID
#        end
#        site_file.puts "<h2> Ad Space Id<#{ad_space_id}></h2>"
#        site_file.puts ad_space.tag.sub("cdsTag.keywords = null;", "cdsTag.zones.as#{ad_space_id}.keywords= { \"sr_k5\" : \"exadtag_#{@campaign1.o_Id}_#{media_buy_id}\" };\n cdsTag.keywords = null;")
#      end
#    end
#    $logger.info "File #{url_site} has been created"
#    site_file.close
#    ie1 = Watir::Browser.new
#    ie1.goto url_site           # put up ad page


    # ie.div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    # sleep 0
    # ie.link(:id,/DownloadAdTags_Button/).click
    # sleep 1
    # ie.link(:text,/Download text files/).click
  end
end
## ==
