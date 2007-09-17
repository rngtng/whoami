require File.dirname(__FILE__) + '/../test_helper'

class UrlCheckerTest < Test::Unit::TestCase

   # Replace this with your real tests.
   def test_truth
      assert true
   end

   ############################
   def test_get_rss_feed( url = 'http://www.raus-aus-kl.de')
      feed_url = UrlChecker.get_feed_url( url )
      assert_equal feed_url, "http://www.raus-aus-kl.de/feed/"
   end
   
   def test_get_rss_feed2( url = 'raus-aus-kl.de')
      feed_url = UrlChecker.check_url( url )
      assert_equal feed_url, "http://www.raus-aus-kl.de/feed/"
   end
   
   ############################
   def test_is_rss_feed( url = 'http://www.raus-aus-kl.de/feed')
      feed_url = UrlChecker.get_feed_url( url )
      assert_equal feed_url, url
   end
   
   def test_is_rss_feed2( url = 'www.raus-aus-kl.de/feed')
      feed_url = UrlChecker.get_feed_url( url )
      assert_equal feed_url, "http://#{url}"
   end
   
   ############################
   def test_is_atom_feed( url = 'http://www.uni-kl.de/aegee/kaiserslautern/atom')
      feed_url = UrlChecker.get_feed_url( url )
      assert_equal feed_url, url
   end
   
end

