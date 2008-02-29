require File.dirname(__FILE__) + '/../test_helper'

class AccountTest < Test::Unit::TestCase
   fixtures :accounts

   # Replace this with your real tests.
   def test_truth
      assert true
   end

   def test_accout_color( account = Account, color = "#000000" )
      assert_equal account.color, color
   end

   def test_lastfmaccout_color()
      test_accout_color( LastfmAccount, "#D01F3C" )
   end

   def test_instance_lastfmaccout_color()
      account =  LastfmAccount.new
      test_accout_color( account, "#D01F3C" )
   end
   
   #########################################################
   def test_account_time( account = Account, time = 5.minutes )
      assert_equal account.worker_update_time, time
   end

   def test_blog_time()
      test_account_time( BlogAccount )
   end

   def test_instance_blog_time()
      account =  BlogAccount.new
      test_account_time( account )
   end
   
   def test_blog_time()
      test_account_time( LastfmAccount, 3.minutes )
   end

   def test_instance_blog_time()
      account =  LastfmAccount.new
      test_account_time( account, 3.minutes )
   end
   
   #########################################################
   def test_accout_requires_host( account = Account, value = false )
      assert_equal account.requires_host?, value
   end

   def test_lastfmaccout_requires_host()
      test_accout_requires_host( LastfmAccount, false )
   end

   def test_instance_lastfmaccout_requires_host()
      account =  LastfmAccount.find :first
      test_accout_requires_host( account, false )
   end

   def test_blogaccout_requires_host()
      test_accout_requires_host( BlogAccount, true )
   end

   def test_instance_blogaccout_requires_host()
      account =  BlogAccount.find :first
      test_accout_requires_host( account, true )
   end

end

