# Pseudocode example of using rollout to roll out a new code path to a subset
# of users.

$rollout = Rollout.new(...)

# Active feature for user
$rollout.activate_user(:colorized, current_user)

# Deactivate feature for user
$rollout.deactivate_user(:colorized, current_user)


# Activate for a percentage of users. The algorithm for determining which users
# get let in is this:
#
#   user.id % 10 < percentage / 10
#
# So, for 20%, users 0, 1, 10, 11, 20, 21, etc would be allowed in.
# Those users would remain in as the percentage increases.
$rollout.activate_percentage(:colorized, 20)

# Deactivate all percentages.
$rollout.deactivate_percentage(:colorized)


def print_notice

  # Only show colorized notices if this feature has been rolled out explicitly
  # to the current user or if they're part of a percentage rollout.
  if $rollout.active?(:colorized, current_user)
    colorized_notice

  else
    ugly_print_notice
  end
end
