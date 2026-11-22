# frozen_string_literal: true

name 'podman'

run_list 'recipe[test::default]'

cookbook 'podman', path: '.'
cookbook 'test', path: './test/cookbooks/test'

Dir.children('./test/cookbooks/test/recipes').grep(/\.rb\z/).sort.each do |recipe|
  recipe_name = File.basename(recipe, '.rb')
  # Kitchen selects the named run list by suite name, and Kitchen turns
  # underscores in suite names into dashes.
  named_run_list recipe_name.tr('_', '-').to_sym, 'recipe[test::' + recipe_name + ']'
end

named_run_list :resources,
               'recipe[test::default]',
               'recipe[test::image]',
               'recipe[test::container]',
               'recipe[test::exec]',
               'recipe[test::pod]',
               'recipe[test::secret]',
               'recipe[test::quadlet]',
               'recipe[test::prune]'
named_run_list :network, 'recipe[test::default]', 'recipe[test::network]', 'recipe[test::network_lifecycle]',
               'recipe[test::network_aux]'
named_run_list :volume, 'recipe[test::default]', 'recipe[test::volume]'
named_run_list :'pod-options', 'recipe[test::default]', 'recipe[test::pod_policy]', 'recipe[test::pod_flags]'
named_run_list :kube, 'recipe[test::default]', 'recipe[test::kube]'
