#!raku

use API::Discord;
use API::Discord::Permissions;
use API::Perspective;

sub MAIN($discord-token, $perspective-token) {
    my $discord = API::Discord.new(:token($discord-token));
    my $perspective = API::Perspective.new(:api-key($perspective-token));

    my Bool $debug = False;
    my SetHash[Str] $monitored-channels .= new();

    $discord.connect;
    await $discord.ready;

    react {
        whenever $discord.messages -> $message {
            my $guild = $message.channel.guild;

            given $message.content {
                if $guild.get-member($message.author).has-any-permission([ADMINISTRATOR]) {
                    when m/^ "+tdebug" $/ {
                        $debug = !$debug;
                        $message.channel.send-message(~$debug);
                    }
                    when m/^ "+tmonitor" $/ {
                        $monitored-channels{$message.channel-id} = !$monitored-channels{$message.channel-id};
                        $message.channel.send-message("<#{$message.channel-id}>" ~ ($monitored-channels{$message.channel-id} ?? ' is now being monitored.' !! ' is no longer being monitored.'));
                    }
                }
                default {
                    if $monitored-channels{$message.channel-id} {
                        my $result = $perspective.analyze(:models[SEVERE_TOXICITY], :comment($message.content));
                        my Rat $toxicity = $result<attributeScores><SEVERE_TOXICITY><summaryScore><value>;

                        given $toxicity { when .8 < * { $message.delete }}

                        if $debug {
                            given $toxicity {
                                when .0 < * <= .1 { $message.add-reaction('😄') }
                                when .1 < * <= .2 { $message.add-reaction('😃') }
                                when .2 < * <= .3 { $message.add-reaction('🙂') }
                                when .3 < * <= .4 { $message.add-reaction('😐') }
                                when .4 < * <= .6 { $message.add-reaction('🙁') }
                                when .6 < * <= .7 { $message.add-reaction('😦') }
                                when .7 < * <= .8 { $message.add-reaction('😠') }
                                default { $message.add-reaction('❓') }
                            }
                        }
                    }
                }
            }
        }
    }
}
