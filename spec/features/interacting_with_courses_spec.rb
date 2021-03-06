require 'rails_helper'
require 'spec_helper'

describe "Interacting with courses", type: :feature do
  Warden.test_mode!

  subject { page }

  after(:each) { Warden.test_reset! }

  before do
    @year          = FactoryGirl.create(:academic_year, :current)
    # FIXME: need to specify deadlines for these quarters?
    @active_q      = FactoryGirl.create(:quarter, :active, published: true,
                                        year: @year.year)
    @inactive_q    = FactoryGirl.create(:quarter, :inactive, published: false,
                                        year: @year.year + 5)
    @admin         = FactoryGirl.create(:admin)
    @faculty       = FactoryGirl.create(:faculty)
    @other_faculty = FactoryGirl.create(:faculty)
    @student       = FactoryGirl.create(:student)
    @other_student = FactoryGirl.create(:student)
    @course_1 = FactoryGirl.create(:course, quarter: @active_q,
                                   instructor: @faculty)
    @aqy = @active_q.year
    @aqs = @active_q.season
    @aqyd = (["winter", "spring"].include? @aqs) ? (@aqy + 1) : @aqy
  end

  # context "in an unpublished quarter" do
  #   # (Not essential)
  # end

  context "in a published quarter" do
    before { visit courses_path(season: @aqs, year: year_slug(@aqy)) }

    context "that have been published" do
      before { @course_1.update_column(:published, true) }

      context "as a guest" do
        it "should have a link on the quarter's page" do
          # We should see a link to them in the courses table, both by navigating
          # to the course page and by visiting the home page*, and we should be
          # able to visit the course page and view its information.

          # (We should be able to click the course link in the table.)

          # * TODO: write a separate spec to check that the active quarter's courses
          # are shown on the homepage, if it's published. If it's not published or
          # it has no courses, show the next immediate quarter's courses (if it
          # exists).

          expect(current_path).to eq(courses_path(season: @aqs, year: year_slug(@aqy)))
          save_and_open_page
          expect(page).to have_content(@course_1.title)
          expect(page).to have_link(@course_1.title)

          click_link(@course_1.title)

          expect(current_path).to eq(q_path(@course_1))
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        it "should not have a link to submit a bid" do
          # FIXME (content and link)
          expect(page).not_to have_content("You can bid")
          expect(page).not_to have_link("My Requests")
        end

        it "should not have a link to edit the course info" do
          expect(page).not_to have_content("edit")
          expect(page).not_to have_link("here")
        end

        it "should redirect if we visit the 'my requests' page" do
          visit my_requests_path(season: @aqs, year: year_slug(@aqy))
          expect(current_path).to eq(root_path) # FIXME: check the root path
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        it "should redirect if we navigate to the 'edit course' path" do
          visit q_path(@course_1, :edit_course)
          expect(current_path).to eq(root_path)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

      end

      context "as a student" do
        before { ldap_sign_in(@student) }

        it "should have a link on the quarter's page" do
          # We should see a link to them in the courses table, both by navigating
          # navigating to the course page and by visiting the home page, and we
          # should be able to visit the course page and view its information.
          expect(current_path).to eq(courses_path(season: @aqs, year: year_slug(@aqy)))
          expect(page).to have_content(@course_1.title)
          expect(page).to have_link(@course_1.title)

          click_link(@course_1.title)

          expect(current_path).to eq(q_path(@course_1))
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        context "before the bidding deadline" do
          before { @active_q.update_column(:student_bidding_deadline,
                                           DateTime.now + 3.days) }

          it "should have a link to submit a bid" do
          expect(page).to have_content("You can bid")
          expect(page).to have_link("My Requests")
          end

          it "should allow saving bids on the 'my requests' page" do
            # FIXME
          end
        end

        context "after the bidding deadline" do
          before { @active_q.update_column(:student_bidding_deadline,
                                           DateTime.now + 3.days) }
          it "should not have a link to submit a bid" do
            expect(page).not_to have_content("You can bid")
            expect(page).not_to have_link("My Requests")
          end

          it "should allow visiting the 'my requests' page" do
            expect(page).to have_selector('.nav') do |nav|
              expect(nav).to have_selector("#dropdown-#{@aqy}-#{@aqs}") do |s|
                click_link "My requests"
                expect(current_path).to eq(my_requests_path(season: @aqs,
                                                            year: year_slug(@aqy)))
              end
            end
          end

          it "should not allow saving bids on the 'my requests' page" do
            # FIXME
          end
        end

        it "should redirect if we visit the 'edit course' page" do
          visit edit_course_path(@course_1)
          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

      end

      context "as the instructor teaching the course" do
        before { ldap_sign_in(@faculty) }

        it "should have a link on the quarter's page" do
          # We should see a link to them in the courses table, both by navigating
          # navigating to the course page and by visiting the home page, and we
          # should be able to visit the course page and view its information.
          expect(current_path).to eq(courses_path(season: @aqs, year: year_slug(@aqy)))
          expect(page).to have_content(@course_1.title)
          expect(page).to have_link(@course_1.title)

          click_link(@course_1.title)

          expect(current_path).to eq(q_path(@course_1))
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        it "should not have a link to the 'my requests' page" do
          expect(page).not_to have_content("You can bid")
          expect(page).not_to have_link("My Requests")
        end

        it "should redirect if we visit the 'my requests' page" do
          visit my_requests_path(season: @aqs, year: year_slug(@aqy))

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

        it "should have a link to edit the course info" do
          expect(page).to have_content("edit")
          expect(page).to have_link("here")
        end

        it "should not redirect if we navigate to the 'edit course' path" do
          click_link "here"

          expect(current_path).to eq(edit_course_path(@course_1))
        end

      end

      context "as an instructor not teaching the course" do
        before { ldap_sign_in(@other_faculty) }

        it "should have a link on the quarter's page" do
          # We should see a link to them in the courses table, both by navigating
          # navigating to the course page and by visiting the home page, and we
          # should be able to visit the course page and view its information.
          expect(current_path).to eq(courses_path(season: @aqs, year: year_slug(@aqy)))
          expect(page).to have_content(@course_1.title)
          expect(page).to have_link(@course_1.title)

          click_link(@course_1.title)

          expect(current_path).to eq(q_path(@course_1))
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        it "should not have a link to the 'my requests' page" do
          expect(page).not_to have_content("You can bid")
          expect(page).not_to have_link("My Requests")
        end

        it "should redirect if we navigate to the 'my requests' path" do
          visit my_requests_path(season: @aqs, year: year_slug(@aqy))

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

        it "should not have a link to edit the course info" do
          expect(page).not_to have_content("edit")
          expect(page).not_to have_link("here")
        end

        it "should redirect if we navigate to the 'edit course' path" do
          visit edit_course_path(@course_1)

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

      end

      context "as an admin" do
        # FIXME: Warden is not logging the user in.
        before { ldap_sign_in(@admin) }

        it "should have a link on the quarter's page" do
          # We should see a link to them in the courses table, both by navigating
          # navigating to the course page and by visiting the home page, and we
          # should be able to visit the course page and view its information.
          expect(current_path).to eq(courses_path(season: @aqs, year: year_slug(@aqy)))
          expect(page).to have_content(@course_1.title)
          expect(page).to have_link(@course_1.title)

          click_link(@course_1.title)

          expect(current_path).to eq(q_path(@course_1))
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
       end

        it "should not have a link to submit a bid" do
          expect(page).not_to have_content("You can bid")
          expect(page).not_to have_link("My Requests")
        end

        it "should have a link to edit the course info" do
          expect(page).to have_content("edit")
          expect(page).to have_link("here")
        end

        it "should redirect if we visit the 'my requests' path" do
          visit my_requests_path(season: @aqs, year: year_slug(@aqy))

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

        it "should not redirect if we navigate to the 'edit course' path" do
          click_link "here"

          expect(current_path).to eq(edit_course_path(@course_1))
        end

        # TODO: Add spec to check that we can publish courses and that
        # instructors cannot.

      end
    end

    context "that have not been published" do
      before { @course_1.update_column(:published, false) }

      context "as a guest" do
        it "should not be viewable" do
          expect(page).not_to have_content(@course_1.title)
        end

        it "should redirect if we visit the course's page" do
          visit q_path(@course_1)

          expect(current_path).to eq(root_path)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end
      end

      context "as a student" do
        before { ldap_sign_in(@student) }

        it "should not be viewable" do
          expect(page).not_to have_content(@course_1.title)
        end

        it "should redirect if we visit the course's page" do
          visit q_path(@course_1)

          expect(current_path).to eq(root_path)
          expect(page).not_to have_content("Access denied")
          expect(page).not_to have_selector("div.alert.alert-danger")
        end

        it "should not appear on the 'my requests' page" do
          visit my_requests_path(season: @aqs, year: year_slug(@aqy))
          # FIXME (not urgent)
        end
      end

      context "as the instructor teaching it" do
        before { ldap_sign_in(@faculty) }

        it "should not be viewable on the course index" do
          expect(page).not_to have_content(@course_1.title)
        end

        it "should be viewable on the 'my courses' page" do
          visit my_courses_path(season: @aqs, year: year_slug(@aqy))
          expect(page).to have_content(@course_1.title)
        end

        it "should not redirect if we visit the course's page" do
          visit q_path(@course_1)
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).to not_have_selector("div.alert.alert-danger")
        end

        it "should be editable" do
          expect(page).to have_content("edit")
          expect(page).to have_link("here")

          click_link "here"
          expect(current_path).to eq(edit_course_path(@course_1))
          expect(page).not_to have_content("Access denied")
          expect(page).to not_have_selector("div.alert.alert-danger")
        end
      end

      context "as an unrelated instructor" do
        before { ldap_sign_in(@other_faculty) }

        it "should not be viewable on the course index" do
          expect(page).not_to have_content(@course_1.title)
        end

        it "should redirect if we visit the course's page" do
          visit my_courses_path(season: @aqs, year: year_slug(@aqy))

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end

        it "should not be editable" do
          expect(page).not_to have_content("edit")
          expect(page).not_to have_link("here")

          visit edit_course_path(@course_1)

          expect(current_path).to eq(root_path)
          expect(page).to have_content("Access denied")
          expect(page).to have_selector("div.alert.alert-danger")
        end
      end

      context "as an admin" do
        before { ldap_sign_in(@admin) }

        it "should be viewable on the course index" do
          expect(page).to have_content(@course_1.title)
        end

        it "should not redirect if we visit the course's page" do
          visit q_path(@course_1)
          expect(page).to have_content(@course_1.title)
          expect(page).not_to have_content("Access denied")
          expect(page).to not_have_selector("div.alert.alert-danger")
        end

        it "should be editable" do
          expect(page).to have_content("edit")
          expect(page).to have_link("here")

          click_link "here"
          expect(current_path).to eq(edit_course_path(@course_1))
          expect(page).not_to have_content("Access denied")
          expect(page).to not_have_selector("div.alert.alert-danger")
        end
      end
    end
  end

  # Admins should also be able to create courses in any quarter, published
  # or unpublished, but they should not be able to publish courses in
  # unpublished quarters.

  # Instructors should not be able to create OR PUBLISH courses. They should
  # be able to edit any of their courses, and there are three cases:

  # 1. published course in published quarter;
  # 2. unpublished course in published quarter;
  # 3. unpublished course in unpublished quarter.
  # (Courses cannot be published in unpublished quarters.)

end
