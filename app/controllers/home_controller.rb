class HomeController < ApplicationController
  def index
		@tasks = current_user.tasks.all
		@my_tasks = @tasks.where("my_tasks.progress = :zero OR my_tasks.progress = :nothing", zero: 0, nothing: nil)
		@done_tasks = @tasks.where("my_tasks.progress = ? ", 1)
		@approved_tasks = @tasks.where("my_tasks.progress = ? ", 2)
		# @random_tasks = Task.where(publicity: 1, status: 1).left_outer_joins(:my_tasks).where.not(my_tasks: {user_id: current_user.id}).limit(5).order("RANDOM()")
		@random_tasks = Task.where(publicity: 1, status: 1).where.not(id: current_user.tasks).limit(5).order("RANDOM()")
		@my_score = current_user.score
		if current_user.role != "Kid"
			case current_user.role
			when "Group"
				@groups = current_user.groups
			when "Branch"
				@branches = current_user.branches
				@groups = @branches.map { |b| b.groups }.flatten
			when "Region"
				@regions = current_user.regions
				@groups = @regions.map { |r| r.branches.map { |b| b.groups }.flatten }.flatten
			when "Movement"
				@movements = current_user.movements
				@groups = @movements.map { |m| m.regions.map { |r| r.branches.map { |b| b.groups }.flatten }.flatten }.flatten
			end
			@tasks_to_approve = []
			@kids_with_unapproved_tasks = []
			@groups.each_with_index do |group, index|
				@tasks_to_approve << Task.joins(:my_tasks).where(my_tasks: {user_id: group.kids.ids}).where(my_tasks: {progress: 1}).ids
				@tasks_to_approve[index].each do |task|
					@kids_with_unapproved_tasks << [task, group.kids.joins(:my_tasks).where(my_tasks: {progress: 1, task_id: task}).ids]
				end
			end
			@kids_with_unapproved_tasks.uniq!
			@general_tasks = Task.where(publicity: 1, status: 1).limit(10).order("RANDOM()")
		end
	end


	def leaders
		@regions = Region.all.order("score DESC")
	  @branches = current_user.groups.map{|g| g.branch}.uniq.sort_by(&:score)
		@groups = current_user.groups.map{|g| g.branch}.uniq.map{|b| b.groups}.flatten.sort_by(&:score).reverse
	end

  def assign_task
    @group = Group.find(params[:group])
    @task = Task.find(params[:task])
    if current_user.is_guide(@group)
      @group.kids.each do |k|
        k.tasks << @task if k.tasks.exclude?(@task)
      end
    else
      current_user.tasks << @task if current_user.tasks.exclude?(@task)
    end
    redirect_to root_path
  end

  def change_progress
    puts "****************************************"
    puts "Change Progress"
    if params[:kid_id].present?
      my_task = User.find(params[:kid_id]).my_tasks.find_by(task_id: params[:task_id])
      puts "kid: #{my_task.user.name}"
      puts "task: #{my_task.task.name} from #{my_task.progress}"
      my_task.progress = "approved"
    else
      my_task = current_user.my_tasks.find_by(task_id: params[:task_id])
      puts "task: #{my_task.task.name} from #{my_task.progress}"
      my_task.progress = "done"
    end
    my_task.save
    puts "to #{my_task.progress}"
    redirect_to root_path
  end
end
