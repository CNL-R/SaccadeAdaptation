function SacReview(varargin)
% Eric Nicholas 2017 - UR
global currparams xdat_degrees ydat_degrees timevec plotdegflag

switch nargin
    case 0
        datadir = uigetdir(cd,'Select the directory with the .asc data files'); %set directory containing bdf files
        ascfiles = ls(fullfile(datadir,'*asc'));
        txtfiles = ls(fullfile(datadir,'*txt'));
        
        if exist(fullfile(datadir,'Sacade_review.mat'),'file') == 2
            load(fullfile(datadir,'Sacade_review.mat'))
        else
            
            trlon = 0;
            
            for h = 1:size(ascfiles,1) %first find trial time points in EyeLink data and convert to index values
                trialorderlist = [];
                trialtimelist = [];
                trialidxlist = [];
                
                cfg.dataset = strtrim(fullfile(datadir,ascfiles(h,:)));
                data_eye(h) = ft_preprocessing(cfg);
                
                for i = 1:length(data_eye(h).hdr.orig.msg)
                    msgdat = strsplit(data_eye(h).hdr.orig.msg{i});
                    if strcmp(msgdat(3),'endtrial') == 1
                        if trlon > 0
                            trialorderlist = vertcat(trialorderlist,trlon);
                            trlon = 0;
                            trialend = str2double(msgdat{2});
                            trialtimelist = vertcat(trialtimelist,[trialstart trialend]);
                        elseif trlon == 0;
                        end
                    elseif strcmp(msgdat(3),'ControlR') == 1
                        trlon = 1;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'ControlL') == 1
                        trlon = 2;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'OrthogonalU') == 1
                        trlon = 3;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'OrthogonalD') == 1
                        trlon = 4;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'Probe+') == 1
                        trlon = 5;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'Probe-') == 1
                        trlon = 6;
                        trialstart = str2double(msgdat{2});
                    elseif strcmp(msgdat(3),'Adaptation') == 1
                        trlon = 7;
                        trialstart = str2double(msgdat{2});
                    end
                end
                
                for i = 1:length(trialtimelist)
                    k = 1;
                    idx1 = find(data_eye(h).trial{1}(1,:)==trialtimelist(i,1));
                    idx2 = find(data_eye(h).trial{1}(1,:)==trialtimelist(i,2));
                    if isempty(idx1)
                        idx1 = find(data_eye(h).trial{1}(1,:)==trialtimelist(i,1)+1);
                    end
                    while isempty(idx2)
                        idx2 = find(data_eye(h).trial{1}(1,:)==trialtimelist(i,2)-k);
                        k = k + 1;
                    end
                    trialidxlist = vertcat(trialidxlist, [idx1 idx2]);
                end
                
                trialstatus(h,:) = {trialorderlist trialidxlist ones(length(trialorderlist),1)};
                
                
                for i = 1:length(trialstatus{h,1})
                    event_data = {};
                    for j = 1:length(data_eye(h).hdr.orig.esacc)
                        temp_msg = strsplit(data_eye(h).hdr.orig.esacc{j});
                        if str2double(temp_msg{3}) > data_eye(h).trial{1}(1,trialstatus{h,2}(i,1)) && str2double(temp_msg{3}) < data_eye(h).trial{1}(1,trialstatus{h,2}(i,2))
                            event_data = vertcat(event_data,{temp_msg{3} temp_msg{4} temp_msg{5} temp_msg{6} temp_msg{7} temp_msg{8} temp_msg{9} temp_msg{10} temp_msg{11}});
                        end
                    end
                    events{h,i} = event_data;
                end 
            end
            
            for i = 1:size(txtfiles,1)
                if isempty(regexp(txtfiles(i,:),'\w*adapt\w*','ONCE'))
                    fileID = fopen(strtrim(fullfile(datadir,txtfiles(i,:))));
                    C = textscan(fileID,'%s');
                    params(i,:) = [str2double(C{1}(3,:)) str2double(C{1}(11,:)) str2double(C{1}(5,:)) str2double(C{1}(7,:)) str2double(C{1}(9,:)) 0 1];
                    fclose(fileID);
                else
                    fileID = fopen(strtrim(fullfile(datadir,txtfiles(i,:))));
                    C = textscan(fileID,'%s');
                    params(i,:) = [str2double(C{1}(3,:)) str2double(C{1}(15,:)) str2double(C{1}(5,:)) str2double(C{1}(7,:)) str2double(C{1}(11,:)) str2double(C{1}(9,:)) str2double(C{1}(13,:))];
                    fclose(fileID);
                end
            end
        end
    case 1
        datadir = cd;
        load(fullfile(datadir,varargin{1}))
end

currfile = 1;
currtrial = 1;

xoffset = 1280; %currently hard-coded, add monitor resolution to parameter file and set from there
yoffset = 540;

typestrings = {'ControlR' 'ControlL' 'OrthogonalU' 'OrthogonalD' 'Probe+' 'Probe-' 'Adaptation'};
statusstrings = {'Unreviewed' 'Accepted' 'Rejected'};
targetpos = [];
plotdegflag = 1;

scrsz = get(groot,'screensize');
fig = figure('Position',[scrsz(3)/10 scrsz(4)/6 scrsz(3)/1.3 scrsz(4)/1.5],'MenuBar','none','Name','Saccade Artifact Rejection','NumberTitle','off','KeyPressFcn',@keypress);
xdataxes = axes('Position',[.2 .6 .5 .25],'ylim',[-1280 1280]);
ydataxes = axes('Position',[.2 .25 .5 .25],'ylim',[-540 540]);
replayaxes = axes('Position',[.75 .25 .2 .25],'xlim',[-35 35],'ylim',[-35 35]);
xlabel = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.4 .85 .1 .035],'String','X Position Data','FontSize',14);
ylabel = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.4 .5 .1 .035],'String','Y Position Data','FontSize',14);
eventlabel = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.8 .85 .1 .035],'String','Trial Events','FontSize',14);
filebox = uicontrol('Parent',fig,'Units','Normalized','Style','listbox','Position',[.05 .55 .075 .3],'String',ascfiles,'callback',@whichfile);
eventsbox = uitable('Data',[],'Parent',fig,'Units','Normalized','Position',[.75 .55 .2 .3],'ColumnName',{'Dur'; 's_x'; 's_y'; 'e_x'; 'e_y'; 'amp'; 'p_v'});
currpathtxt = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.05 .9 .45 .025],'String',['Data Directory:  ' datadir],'HorizontalAlignment','left');
filetrials = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.05 .45 .08 .1],'HorizontalAlignment','left');
trialinfo = uicontrol('Parent',fig,'Units','Normalized','Style','text','Position',[.05 .35 .1 .08],'HorizontalAlignment','left');
paraminfo = uicontrol('Parent',fig','Units','Normalized','Style','text','Position',[.05 .25 .1 .08],'HorizontalAlignment','left');

playbutton = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Play Trial','Position',[.82 .15 .05 .05],'callback',@playtrial);
prevbutton = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','<Prev Trial','Position',[.2 .155 .05 .03],'callback',@prevtrial);
nextbutton = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Next Trial>','Position',[.37 .155 .05 .03],'callback',@nextrial);
acceptbutton = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Accept Trial','Position',[.26 .15 .05 .04],'callback',@accept);
rejectbutton = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Reject Trial','Position',[.31 .15 .05 .04],'callback',@reject);
saverevbut = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Save Review State','Position',[.45 .15 .075 .05],'callback',@savereview);
outbutt = uicontrol('Parent',fig,'Units','Normalized','Style','pushbutton','String','Create Data Struct','Position',[.55 .15 .075 .05],'callback',@dataout);
plotdegcheck = uicontrol('Parent',fig,'Units','Normalized','Style','checkbox','Position',[.2 .1 .05 .03],'callback',@plotdegrees,'Value',1);
plotdegtxt = uicontrol('Parent',fig','Units','Normalized','Style','text','Position',[.21 .1 .1 .025],'HorizontalAlignment','left','String','Plot data in Degrees');

whichfile(filebox)
updateinfo
plottrial
savereview

    function whichfile(src,~)
        currfile = get(src,'Value');
        currtrial = 1;
        
        currparams = params(currfile,:);
        targetpos = [currparams(4) currparams(4)*-1 currparams(5)*-1 currparams(5) currparams(4)*currparams(7) currparams(4)*currparams(7)*-1 currparams(4)*currparams(7) currparams(6)*currparams(7)];
        if currparams(6) == 0
            set(paraminfo,'String',{['Target1 dist: ' num2str(targetpos(1)) ' degrees']; ['Orthogonal dist: ' num2str(targetpos(4)) ' degrees']});
        else
            set(paraminfo,'String',{['Target1 dist: ' num2str(targetpos(7)) ' degrees']; ['Target2 dist: ' num2str(targetpos(8)) ' degrees']; ['AdaptDir: ' num2str(currparams(7)) '  (1 = R, -1 = L)'];...
                ['Orthogonal dist: ' num2str(targetpos(4)) ' degrees']});
        end
        
        updateinfo
        plottrial
    end

    function updateinfo
        set(filetrials,'String',{['Trials in file:  ' num2str(length(trialstatus{currfile,1}))];...
            ['nControl:  ' num2str(length(find(trialstatus{currfile,1}==1 | trialstatus{currfile,1}==2)))];...
            ['nOrthogonal:  ' num2str(length(find(trialstatus{currfile,1}==3 | trialstatus{currfile,1}==4)))];...
            ['nProbe:  ' num2str(length(find(trialstatus{currfile,1}==5 | trialstatus{currfile,1}==6)))];...
            ['nAdaptation:  ' num2str(length(find(trialstatus{currfile,1}==7)))]});
        set(trialinfo,'String',{['Current trial: ' num2str(currtrial)];['Trial type: ' typestrings{trialstatus{currfile,1}(currtrial)}];...
            ['Trial status: ' statusstrings{trialstatus{currfile,3}(currtrial)}];['Unreviewed Trials: ' num2str(length(find(trialstatus{currfile,3} == 1)))]});
        set(eventsbox,'Data',events{currfile,currtrial}(:,3:end));
    end

    function prevtrial(~,~)
        currtrial = currtrial - 1;
        if currtrial < 1
            currtrial = length(trialstatus{currfile,1});
        end
        updateinfo
        plottrial
    end

    function nextrial(~,~)
        currtrial = currtrial + 1;
        if currtrial > length(trialstatus{currfile,1})
            currtrial = 1;
        end
        updateinfo
        plottrial
    end

    function keypress(~,evt)
        if strcmp(evt.Key,'rightarrow') == 1
            nextrial
        elseif strcmp(evt.Key,'leftarrow') == 1
            prevtrial
        elseif strcmp(evt.Key,'r') == 1
            reject
        elseif strcmp(evt.Key,'a') == 1
            accept
        end
    end

    function accept(~,~)
        trialstatus{currfile,3}(currtrial) = 2;
        updateinfo
        nextrial
    end

    function reject(~,~)
        trialstatus{currfile,3}(currtrial) = 3;
        updateinfo
        nextrial
    end

    function plotdegrees(hobj,~)
        if (get(hobj,'Value') == get(hobj,'Max'))
            plotdegflag = 1;
        else
            plotdegflag = 0;
        end
        plottrial
    end

    function playtrial(~,~)
        for p = 1:length(xdat_degrees)
            plot(replayaxes,xdat_degrees(p),ydat_degrees(p),'o','MarkerSize',10);
            hold(replayaxes,'on');
            if trialstatus{currfile,1}(currtrial) == 3 || trialstatus{currfile,1}(currtrial) == 4
                plot(replayaxes,0,targetpos(trialstatus{currfile,1}(currtrial)),'g.','MarkerSize',20);
            elseif trialstatus{currfile,1}(currtrial) == 7
                plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)),0,'g.','MarkerSize',20);
                plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)+1),0,'r.','MarkerSize',20);
            else
                plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)),0,'g.','MarkerSize',20);
            end
            %plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)),0,'g.','MarkerSize',20);
            %plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)+1),0,'r.','MarkerSize',20);
            plot(replayaxes,[-35 35],[0 0],'k--'); plot(replayaxes,[0 0],[-25 25],'k--');
            hold(replayaxes,'off');
            set(replayaxes,'xlim',[-35 35],'ylim',[-25 25]);
            
            plot(xdataxes,timevec,xdat_degrees); hold(xdataxes,'on');
            plot(xdataxes,timevec(p),xdat_degrees(p),'bo','MarkerSize',10); hold(xdataxes,'off');
            set(xdataxes,'ylim',[-35 35]);
            
            plot(ydataxes,timevec,ydat_degrees); hold(ydataxes,'on');
            plot(ydataxes,timevec(p),ydat_degrees(p),'bo','MarkerSize',10); hold(ydataxes,'off');
            set(ydataxes,'ylim',[-25 25]);
            
            pause(.00025)
        end
        plottrial
    end

    function plottrial
        
        xdat_degrees = rad2deg(atan((((data_eye(currfile).trial{1}(2,trialstatus{currfile,2}(currtrial,1):trialstatus{currfile,2}(currtrial,2))-xoffset).*currparams(2))./currparams(1))));
        ydat_degrees = rad2deg(atan((((data_eye(currfile).trial{1}(3,trialstatus{currfile,2}(currtrial,1):trialstatus{currfile,2}(currtrial,2))-yoffset).*currparams(2))./currparams(1))));
        timevec = 0:1/data_eye(1).hdr.Fs:1/data_eye(1).hdr.Fs*(length(data_eye(currfile).trial{1}(2,trialstatus{currfile,2}(currtrial,1):trialstatus{currfile,2}(currtrial,2)))-1);
        
        if trialstatus{currfile,1}(currtrial) == 1 || trialstatus{currfile,1}(currtrial) == 2
            whichax = xdataxes;
            plot1target
        elseif trialstatus{currfile,1}(currtrial) == 3 || trialstatus{currfile,1}(currtrial) == 4
            whichax = ydataxes;
            plot1target
        elseif trialstatus{currfile,1}(currtrial) == 5 || trialstatus{currfile,1}(currtrial) == 6
            whichax = xdataxes;
            plot1target
        else
            whichax = xdataxes;
            plot2targets
        end
        
        function plot1target
            plot(whichax,timevec,...
                repmat(targetpos(trialstatus{currfile,1}(currtrial)),1,length(xdat_degrees)),'r');
            if trialstatus{currfile,1}(currtrial) == 3 || trialstatus{currfile,1}(currtrial) == 4
                plot(replayaxes,0,targetpos(trialstatus{currfile,1}(currtrial)),'g.','MarkerSize',20);
            else
                plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)),0,'g.','MarkerSize',20);
            end
            hold(replayaxes,'on');
            hold(whichax,'on');
        end
        function plot2targets
            plot(whichax,timevec,...
                repmat(targetpos(trialstatus{currfile,1}(currtrial)+1),1,length(xdat_degrees)),'r');
            plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)),0,'g.','MarkerSize',20);
            hold(replayaxes,'on');
            hold(whichax,'on');
            plot(whichax,timevec,...
                repmat(targetpos(trialstatus{currfile,1}(currtrial)),1,length(xdat_degrees)),'g');
            plot(replayaxes,targetpos(trialstatus{currfile,1}(currtrial)+1),0,'r.','MarkerSize',20);
        end
        
        if plotdegflag == 1
            plot(xdataxes,timevec,xdat_degrees);
            set(xdataxes,'ylim',[-35 35]);
            
            plot(ydataxes,timevec,ydat_degrees);
            set(ydataxes,'ylim',[-25 25]);
            
            hold(whichax,'off')
        else
            plot(xdataxes,timevec,...
                data_eye(currfile).trial{1}(2,trialstatus{currfile,2}(currtrial,1):trialstatus{currfile,2}(currtrial,2))-xoffset);
            set(xdataxes,'ylim',[-xoffset xoffset]);
            plot(ydataxes,timevec,...
                data_eye(currfile).trial{1}(3,trialstatus{currfile,2}(currtrial,1):trialstatus{currfile,2}(currtrial,2))-yoffset);
            set(ydataxes,'ylim',[-yoffset yoffset]);
            hold(whichax,'off')
        end
        
        plot(replayaxes,xdat_degrees(1),ydat_degrees(1),'bo','MarkerSize',10); set(replayaxes,'xlim',[-35 35],'ylim',[-25 25])
        plot(replayaxes,[-35 35],[0 0],'k--'); plot(replayaxes,[0 0],[-25 25],'k--');
        hold(replayaxes,'off');
    end

    function savereview(~,~)
        filename = 'Sacade_review.mat';
        save(fullfile(datadir,filename),'data_eye','trialstatus','params','events','ascfiles','txtfiles');
    end

    function dataout(~,~)
        dataout = struct('type',[],'code',[],'pixdata',[],'degdata',[]);
        for p = 1:length(trialstatus)
            keepers = find(trialstatus{p,3} == 2);
            for m = 1:length(keepers)
                if p == 1
                    dataout(m).type = typestrings{trialstatus{p,1}(m)};
                    dataout(m).code = trialstatus{p,1}(m);
                    dataout(m).pixdata(1,:) = data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset;
                    dataout(m).pixdata(2,:) = data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset;
                    dataout(m).degdata(1,:) = rad2deg(atan((((data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset).*params(p,2))./params(p,1))));
                    dataout(m).degdata(2,:) = rad2deg(atan((((data_eye(p).trial{1}(3,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-yoffset).*params(p,2))./params(p,1))));
                else
                    dataout(length(dataout)+1).type = typestrings{trialstatus{p,1}(m)};
                    dataout(length(dataout)).code = trialstatus{p,1}(m);
                    dataout(length(dataout)).pixdata(1,:) = data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset;
                    dataout(length(dataout)).pixdata(2,:) = data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset;
                    dataout(length(dataout)).degdata(1,:) = rad2deg(atan((((data_eye(p).trial{1}(2,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-xoffset).*params(p,2))./params(p,1))));
                    dataout(length(dataout)).degdata(2,:) = rad2deg(atan((((data_eye(p).trial{1}(3,trialstatus{p,2}(keepers(m),1):trialstatus{p,2}(keepers(m),2))-yoffset).*params(p,2))./params(p,1))));                    
                end
            end
            clear keepers
        end
        assignin('base', 'dataout', dataout);
    end

end