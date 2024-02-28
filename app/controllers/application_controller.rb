class ApplicationController < ActionController::Base

#  Add for devise authantication
  before_action :authenticate_user!

end
