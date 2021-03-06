class CoursesController < ApplicationController

  include CoursePatterns

  before_action :find_course, only: [:show, :create, :edit, :update, :destroy,
                                     :student_requests]
  # before_action :find_courses, only: [:global_index, :index, :drafts]

  load_and_authorize_resource find_by: :number

  before_action :authenticate_user!, except: [:global_index, :index, :show]

  before_action :get_quarter,            only: [:show, :index, :drafts, :new,
                                                :create, :destroy,
                                                :student_requests]
  before_action :get_year_and_season,    only: [:create, :update]
  before_action :get_courses_in_qrtr,    only: [:index, :drafts]
  before_action :get_num_courses_arr,    only: :show
  before_action :get_bid,                only: :show
  before_action :get_db_course,          only: [:edit, :update]
  before_action :get_db_instructor_cnet, only: [:edit, :update]
  before_action :get_instructors,        only: [:new, :create, :edit, :update]
  before_action :get_instructor,         only: [:create, :update]

  before_action(only: [:show, :edit]) { |c|
    c.redirect_if_wrong_quarter_params(@course) }

  def show
  end

  def student_requests
    top_requesters   = []
    other_requesters = []
    id               = @course.id

    Student.all.each do |s|
      top_courses = s.number_of_courses
      s.bids.each do |b|
        if b.course_id == id
          (b.preference > top_courses ? other_requesters : top_requesters) << s
          break
        end
      end
    end

    @top_requesters   = Student.where(id: top_requesters.map(&:id))
    @other_requesters = Student.where(id: other_requesters.map(&:id))
  end

  def global_index
    y = year_unslug(params[:year])
    s = params[:season].try(:downcase)
    active = Quarter.active_quarter
    @quarter = y && s ? Quarter.find_by(year: y, season: s) : active
    @courses = @quarter ? @quarter.published_courses : []
  end

  def index
    @courses = @courses.where(draft: false)
    @published_courses = @courses.where(published: true)
  end

  def drafts
    @courses = @courses.where(draft: true)
  end

  def new
  end

  def create
    # FIXME: Use a symbol other than :instructor_id here and in #update?
    @quarter = Quarter.find_by(year: year_unslug(params[:year]),
                               season: params[:season])

    if params[:course][:instructor_id] == "TBD"
      params[:course][:instructor_id] = nil
      @course = Course.new(course_params)
      @course.assign_attributes(quarter_id: @quarter.id,
                                instructor_id: nil)
      instructor = nil
    else
      params[:course][:instructor_id] = @instructor.id
      @course = @instructor.courses.build(course_params)
      @course.assign_attributes(quarter_id: @quarter.id,
                                instructor_id: @instructor.id)
      instructor = Faculty.find(params[:course][:instructor_id])
    end

    @selected_instructor_cnet = instructor ? instructor.cnet : "TBD"

    save 'new'
  end

  def edit
    @selected_instructor_cnet = "TBD" if !@course.instructor
  end

  def update
    params[:course][:instructor_id] = @instructor.id if @instructor

    if @course.draft?
      @course.assign_attributes(course_params)
      save 'edit'
    else
      if @course.update_attributes(course_params)
        flash[:success] = "Course information successfully updated."
        redirect_to q_path(@course)
      else
        render 'edit'
      end
    end
  end

  def destroy
    if @course.destroy
      flash[:success] = "Course successfully deleted."
      redirect_to courses_path(year: year_slug(@quarter.year),
                               season: @quarter.season) and return
    else
      flash[:error] = "Course could not be deleted."
      render 'show'
    end
  end

  private

  def course_params
    case current_user.type
    when "Admin"
      params.require(:course).permit(:title, :instructor_id, :syllabus,
                                     :number, :prerequisites, :time, :location,
                                     :website, :satisfies, :published,
                                     :course_prerequisites)
    when "Faculty"
      params.require(:course).permit(:syllabus, :prerequisites, :website,
                                     :satisfies, :course_prerequisites)
    end
  end

  def get_year_and_season
    @year   = params[:year]
    @season = params[:season]
  end

  def get_courses_in_qrtr
    @courses = Course.where(quarter_id: @quarter.id)
  end

  def get_bid
    if current_user.try(:student?)
      @bid = Bid.find_by(course_id: @course.id,
                         student_id: current_user.id) || current_user.bids.new
    end
  end

  def get_db_course
    # We use the course from the database so that we don't try to update the
    # wrong course if the instructor first tries to save an invalid course
    # (e.g., by changing the number or title to another course's) and then
    # corrects their mistake.
    @db_course = Course.find(@course.id)
  end

  def get_db_instructor_cnet
    @db_instructor_cnet =
     if @course.instructor_id && @course.instructor_id > 0
       Faculty.find(@course.instructor_id).try(:cnet)
     else
       nil
     end
  end

  def get_instructors
    @instructors = Faculty.all.map { |f| [f.full_name, f.cnet] }
  end

  def get_instructor
    # @instructor is nil if a faculty member is editing their course
    @instructor = Faculty.find_by(cnet: params[:course][:instructor_id])
  end

  def find_course
    n = params[:id]
    y = year_unslug(params[:year])
    s = params[:season]

    @course =
    if n && y && s
      q = Quarter.find_by(year: y, season: s)
      q ? Course.find_by(number: n, quarter: q) : nil
    elsif n
      Course.find_by(number: n)
    else
      nil
    end
  end

end
