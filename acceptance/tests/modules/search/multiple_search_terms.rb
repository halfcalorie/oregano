test_name 'oregano module search should handle multiple search terms sensibly'

tag 'audit:low',
    'audit:unit',
    'audit:delete'

#step 'Setup'
#stub_forge_on(master)

# FIXME: The Forge doesn't properly handle multi-term searches.
# step 'Search for a module by description'
# on master, oregano("module search 'notice here'") do
#   assert stdout !~ /'notice here'/
# end
#
# step 'Search for a module by name'
# on master, oregano("module search 'ance-geo ance-std'") do
#   assert stdout !~ /'ance-geo ance-std'/
# end
#
# step 'Search for multiple keywords'
# on master, oregano("module search 'star trek'") do
#   assert stdout !~ /'star trek'/
# end
