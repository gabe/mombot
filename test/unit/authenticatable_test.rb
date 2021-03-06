require File.dirname(__FILE__) + '/../test_helper'

class AuthenticatableTest < ActiveSupport::TestCase
  
  def setup
    clean_db
  end
  
  def teardown
    clean_db
  end
  
  def clean_db
    bob = User.first(:conditions => "identity = 'nonexistingbob'")
    bob.delete if bob
  end

  test "new users should not be admins" do
    u = User.new
    u.save
    assert_false u.admin?
  end
  
  test "authenticates only valid user/pass combos" do
    #check that we can identity a valid user
    Factory :dispensed_pez, :identity => 'bob'
    bob = Factory :bob
    assert_equal  bob, User.authenticate("bob", "test")
    #wrong username
    assert_nil    User.authenticate("nonbob", "test")
    #wrong password
    assert_nil    User.authenticate("bob", "wrongpass")
    #wrong identity and pass
    assert_nil    User.authenticate("nonbob", "wrongpass")
  end
  
  test "disables old password on password change" do
    # check success
    Factory :dispensed_pez, :identity => 'longbob'
    @longbob = Factory :longbob
    assert_equal @longbob, User.authenticate("longbob", "longtest")
    #change password
    @longbob.password = @longbob.password_confirmation = "nonbobpasswd"
    assert @longbob.save
    #new password works
    assert_equal @longbob, User.authenticate("longbob", "nonbobpasswd")
    #old pasword doesn't work anymore
    assert_nil   User.authenticate("longbob", "longtest")
    #change back again
    @longbob.password = @longbob.password_confirmation = "longtest"
    assert @longbob.save
    assert_equal @longbob, User.authenticate("longbob", "longtest")
    assert_nil   User.authenticate("longbob", "nonbobpasswd")
  end
  
  test "does not allow short/long/empty passwords" do
    #check thaat we can't create a user with any of the disallowed paswords
    pez = Factory :dispensed_pez, :identity => 'nonbob'
    u = User.new    
    u.identity = "nonbob"
    u.email = "nonbob@mcbob.com"
    u.secret_code = pez.secret_code
    #too short
    u.password = u.password_confirmation = "z" 
    assert !u.save     
    assert u.errors.invalid?('password')
    #too long
    u.password = u.password_confirmation = "hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge"
    assert !u.save     
    assert u.errors.invalid?('password')
    #empty
    u.password = u.password_confirmation = ""
    assert !u.save    
    assert u.errors.invalid?('password')
    #ok
    u.password = u.password_confirmation = "bobs_secure_password"
    assert u.save     
    assert u.errors.empty? 
  end
  
  test "does not allow invalid identities" do
    #check we cant create a user with an invalid username
    pez = Factory :dispensed_pez
    u = User.new  
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "okbob@mcbob.com"
    u.secret_code = pez.secret_code
    #too short
    Factory :dispensed_pez, :identity => 'x'
    u.identity = "x"
    assert !u.save     
    assert u.errors.invalid?('identity')
    #too long
    Factory :dispensed_pez, :identity => 'hugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhug'
    u.identity = "hugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhug"
    assert !u.save     
    assert u.errors.invalid?('identity')
    #empty
    Factory :dispensed_pez, :identity => ''
    u.identity = ""
    assert !u.save
    assert u.errors.invalid?('identity')
    #ok
    Factory :dispensed_pez, :identity => 'okbob'
    u.identity = "okbob"
    assert u.save  
    assert u.errors.empty?
    #no email
    u.email=nil   
    assert !u.save     
    assert u.errors.invalid?('email')
    #invalid email
    u.email='notavalidemail'   
    assert !u.save     
    assert u.errors.invalid?('email')
    #ok
    u.email="validbob@mcbob.com"
    assert u.save  
    assert u.errors.empty?
  end

  test "does not allow creation of a user with an existing name" do
    existing = Factory :user, :identity => 'existingbob'
    u = User.new
    u.identity = "existingbob"
    u.email = "already@taken.org"
    u.password = u.password_confirmation = "bobs_secure_password"
    u.secret_code = existing.secret_code
    assert !u.save
    assert u.errors.invalid?('identity')
  end
  
  test "authenticates new users" do
    #check create works and we can authenticate after creation
    pez = Factory :dispensed_pez, :identity => 'nonexistingbob'
    u = User.new
    u.identity = "nonexistingbob"
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "nonexistingbob@mcbob.com"
    u.secret_code = pez.secret_code
    assert_not_nil u.salt
    assert u.save
    assert_equal 10, u.salt.length
    assert_equal u, User.authenticate(u.identity, u.password)
  
    new_pez = Factory :dispensed_pez, :identity => 'newbob'
    u = User.new :identity => "newbob", 
                 :password => "newpassword", 
                 :password_confirmation => "newpassword", 
                 :email => "newbob@mcbob.com",
                 :secret_code => new_pez.secret_code
    assert_not_nil u.salt
    assert_not_nil u.password
    assert_not_nil u.hashed_password
    assert u.save 
    assert_equal u, User.authenticate(u.identity, u.password)
  end
  
  test "sends email when new password requested" do
    #check user authenticates
    Factory :dispensed_pez, :identity => 'bob'
    @bob = Factory :bob
    assert_equal  @bob, User.authenticate("bob", "test")    
    #send new password
    sent = @bob.send_new_password
    assert_not_nil sent
    #old password no longer workd
    assert_nil User.authenticate("bob", "test")
    #email sent...
    assert_equal "Your password is ...", sent.subject
    #... to bob
    assert_equal @bob.email, sent.to[0]
    assert_match Regexp.new("Your identity is bob."), sent.body
    #can authenticate with the new password
    new_pass = $1 if Regexp.new("Your new password is (\\w+).") =~ sent.body 
    assert_not_nil new_pass
    assert_equal  @bob, User.authenticate("bob", new_pass)    
  end
  
  test "random string does not collide with old password" do
    new_pass = Secrets.random_string(10)
    assert_not_nil new_pass
    assert_equal 10, new_pass.length
  end
  
  test "hashes passwords based on salt" do
    pez = Factory :dispensed_pez, :identity => 'nonexistingbob'
    u = User.new
    u.identity = "nonexistingbob"
    u.email = "nonexistingbob@mcbob.com"
    u.salt = "1000"
    u.password = u.password_confirmation = "bobs_secure_password"
    u.secret_code = pez.secret_code
    assert u.save   
    assert_equal 'b1d27036d59f9499d403f90e0bcf43281adaa844', u.hashed_password
    assert_equal 'b1d27036d59f9499d403f90e0bcf43281adaa844', Secrets.encrypt("bobs_secure_password", "1000")
  end
  
  test "protects id and salt attributes from user tampering" do
    #check attributes are protected
    pez = Factory :dispensed_pez, :identity => 'badbob'
    u = User.new :id => 999999, 
                 :salt => "I-want-to-set-my-salt", 
                 :identity => "badbob", 
                 :password => "newpassword", 
                 :password_confirmation => "newpassword", 
                 :email => "badbob@mcbob.com",
                 :secret_code => pez.secret_code
    assert u.save
    assert_not_equal 999999, u.id
    assert_not_equal "I-want-to-set-my-salt", u.salt
  
    u.update_attributes(:id=>999999, :salt=>"I-want-to-set-my-salt", :identity => "verybadbob")
    assert u.save
    assert_not_equal 999999, u.id
    assert_not_equal "I-want-to-set-my-salt", u.salt
    assert_equal "verybadbob", u.identity
  end

end
