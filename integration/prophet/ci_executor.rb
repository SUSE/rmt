module SCC

  # FailedStepExecution
  class FailedStepExecution < RuntimeError; end

  # RunStep
  class RunStep
    attr_accessor :name, :command, :status, :project

    def initialize(name: nil, command: nil, project:)
      @name    = name
      @command = command
      @project = project
      @status = true
    end

    def run!
      @status = system(command)
      raise FailedStepExecution, "Failed fast in project #{project.name} on step #{name}." unless @status
    end

    def text_status
      status ? "passed -- #{name}" : "failed -- #{name}"
    end
  end

  # Project
  class Project
    attr_accessor :name, :steps

    def initialize(name: nil, steps: [])
      @name = name
      @steps = steps
    end

    def run!
      steps.each(&:run!)
    end

    def status
      steps.all?(&:status)
    end

    def text_status
      status ? "#{name} is all green" : "#{name} failed"
    end

    def requires_testing?
      if defined? @requires_testing
        @requires_testing
      else
        @requires_testing = begin
          any_different = system('git diff HEAD..origin/master --exit-code --quiet -- .')
          if any_different
            CiExecutor.logger.info "Skipping #{name} - as no changes detected"
            false
          else
            CiExecutor.logger.info "Testing #{name} - as changes detected"
            true
          end
        end
      end
    end
  end

  # CiExecutor
  class CiExecutor
    class << self
      attr_accessor :logger
    end

    attr_accessor :status, :projects, :logger, :fail_message

    def initialize(logger: nil)
      self.class.logger = logger
      @projects = []
      YAML.load_file(File.expand_path('.prophet_ci.yml', __dir__))['projects'].each_pair do |project_name, run_steps|
        project = Project.new(name: project_name)
        run_steps.each_pair { |name, cmd| project.steps << RunStep.new(name: name, command: cmd, project: project) }
        @projects << project
      end
    end

    def run!
      projects.each(&:run!)
    rescue FailedStepExecution => e
      @fail_message = e.to_s
      CiExecutor.logger.info e if CiExecutor.logger
    end

    def inspect_failed
      failed_projects.each do |prj|
        CiExecutor.logger.info prj.text_status
        prj.steps.each do |step|
          CiExecutor.logger.info '|----' + step.text_status
          break unless step.status
        end
      end
    end

    def success?
      projects.all?(&:status)
    end

    def failed_projects
      projects.reject(&:status)
    end
  end
end
