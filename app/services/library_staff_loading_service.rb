# frozen_string_literal: true

# This class is responsible for refreshing the
# library_staff_document table from the csv
# file generated by lib-jobs
class LibraryStaffLoadingService < CSVLoadingService
  private

  def class_to_load
    LibraryStaffRecord
  end

  def data_is_valid?
    return false if csv_is_much_smaller?

    csv.readline == %w[PUID NetID Phone Name lastName firstName middleName Title LibraryTitle
                       LongTitle Email Section Division Department StartDate StaffSort UnitSort DeptSort Unit DivSect FireWarden BackupFireWarden FireWardenNotes Office Building]
  end

  def uri
    @uri ||= URI.parse('https://lib-jobs.princeton.edu/staff-directory.csv')
  end
end
